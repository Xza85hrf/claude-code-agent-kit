# Local RAG API Recipe

Build a fully local RAG endpoint with Ollama (embeddings + generation), ChromaDB (vector store), and FastAPI. Zero cloud dependencies.

## Architecture Overview

```
Ingestion:     Read → Chunk (by paragraph) → Embed (nomic-embed-text) → Store (ChromaDB)
Query:         Query → Embed → Retrieve (cosine similarity) → Augment (LLM context) → Generate
Multi-tenant:  Metadata filtering: where={"user_name": "alice"}
```

## Ollama Embedding Function for ChromaDB

Wrapper to use `nomic-embed-text:latest` for vector embeddings:

```python
import ollama
from chromadb.api.types import EmbeddingFunction

class OllamaEmbedding(EmbeddingFunction):
    def __init__(self, model: str = "nomic-embed-text:latest"):
        self.model = model

    def __call__(self, texts: list[str]) -> list[list[float]]:
        """Embed a list of texts using Ollama."""
        embeddings = []
        for text in texts:
            response = ollama.embeddings(
                model=self.model,
                prompt=text
            )
            embeddings.append(response['embedding'])
        return embeddings
```

**Install:** `pip install chromadb ollama`

## ChromaDB Setup

### Persistent Client with Multi-Tenant Collections

```python
import chromadb

# Connect to persistent vector store
client = chromadb.PersistentClient(path="./chroma_db")

# Create or get collection with embedding function
embedding_fn = OllamaEmbedding()
collection = client.get_or_create_collection(
    name="documents",
    metadata={"hnsw:space": "cosine"},
    embedding_function=embedding_fn
)
```

### Document Storage with Metadata

```python
def ingest_document(collection, text: str, user_name: str, source: str):
    """Ingest a document with user-scoped metadata."""
    # Chunk by paragraph
    chunks = [p.strip() for p in text.split('\n\n') if p.strip()]

    for i, chunk in enumerate(chunks):
        collection.add(
            ids=[f"{source}_{i}"],
            documents=[chunk],
            metadatas=[{
                "user_name": user_name,
                "source": source,
                "chunk_index": i,
                "created_at": datetime.now().isoformat()
            }]
        )
```

## Chunking Strategy

```python
def chunk_text(text: str, chunk_size: int = 512, overlap: int = 50) -> list[str]:
    """
    Split text by paragraphs first, then by character overlap if needed.
    Ignore empty chunks.
    """
    # Split by double newline (paragraph break)
    paragraphs = [p.strip() for p in text.split('\n\n') if p.strip()]

    chunks = []
    for para in paragraphs:
        if len(para) <= chunk_size:
            chunks.append(para)
        else:
            # Split long paragraphs with overlap
            words = para.split()
            window = []
            for word in words:
                window.append(word)
                if len(' '.join(window)) > chunk_size:
                    chunks.append(' '.join(window[:-1]))
                    window = window[-(overlap // 10):]  # Overlap by ~50 chars
            if window:
                chunks.append(' '.join(window))

    return [c for c in chunks if c]  # Filter empty
```

## FastAPI Endpoints

### Main RAG Application

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import ollama

app = FastAPI()

class AskRequest(BaseModel):
    query: str
    user_name: str
    top_k: int = 3
    generation_model: str = "mistral:latest"

class DocumentRequest(BaseModel):
    text: str
    user_name: str
    source: str

@app.post("/documents")
async def ingest(req: DocumentRequest):
    """Ingest a document into the vector store."""
    try:
        ingest_document(collection, req.text, req.user_name, req.source)
        return {"status": "ingested", "source": req.source}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/ask")
async def ask(query: str, user_name: str, top_k: int = 3):
    """
    Retrieve relevant documents + generate answer.
    """
    try:
        # Retrieve with user-scoped filtering
        results = collection.query(
            query_texts=[query],
            n_results=top_k,
            where={"user_name": user_name}  # Multi-tenant filter
        )

        if not results['documents'][0]:
            return {
                "query": query,
                "context": [],
                "answer": "No relevant documents found.",
            }

        # Build context from top-k chunks
        context = "\n\n".join(results['documents'][0])

        # Generate answer with context
        prompt = f"""Answer the following question based on the provided context.
If the context doesn't contain relevant information, say so.

Context:
{context}

Question: {query}

Answer:"""

        response = ollama.generate(
            model="mistral:latest",
            prompt=prompt,
            stream=False
        )

        return {
            "query": query,
            "context": results['documents'][0],
            "distances": results['distances'][0],  # Cosine similarity scores
            "answer": response['response'].strip(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health():
    return {"status": "healthy"}
```

## Multi-Tenant Pattern

Filter documents by user at query time:

```python
def retrieve_for_user(collection, query: str, user_name: str, top_k: int = 3):
    """Retrieve only documents accessible to a specific user."""
    return collection.query(
        query_texts=[query],
        n_results=top_k,
        where={"user_name": user_name}
    )

# Optional: Additional metadata filtering
def retrieve_with_source(collection, query: str, user_name: str, source: str, top_k: int = 3):
    """Filter by both user and document source."""
    return collection.query(
        query_texts=[query],
        n_results=top_k,
        where={
            "$and": [
                {"user_name": user_name},
                {"source": source}
            ]
        }
    )
```

## Prompt Template with Fallback

```python
ANSWER_TEMPLATE = """You are a helpful assistant. Answer the question based on the provided context.

Context:
{context}

Question: {question}

Rules:
- If the context contains relevant information, use it to answer.
- If the context doesn't help, say: "I don't have information about that."
- Be concise but complete.
- Cite sources when possible (e.g., "According to the documentation...").

Answer:"""

def generate_with_fallback(query: str, context: str, model: str = "mistral:latest") -> str:
    """Generate answer with fallback to generic response if no context."""
    if not context or context.strip() == "":
        return "I don't have enough information to answer that question."

    prompt = ANSWER_TEMPLATE.format(context=context, question=query)
    response = ollama.generate(model=model, prompt=prompt, stream=False)
    return response['response'].strip()
```

## Run Locally

```bash
# Start Ollama (pull models first if needed)
ollama serve &

# Pull models
ollama pull mistral:latest
ollama pull nomic-embed-text:latest

# Start RAG API
pip install fastapi uvicorn chromadb ollama
uvicorn main:app --reload --port 8000

# Test
curl -X POST http://localhost:8000/documents \
  -H "Content-Type: application/json" \
  -d '{
    "text": "The sky is blue. Clouds are white.",
    "user_name": "alice",
    "source": "weather_facts"
  }'

curl "http://localhost:8000/ask?query=What%20color%20is%20the%20sky&user_name=alice"
```

## Optional: Streaming Responses

For long-form answers, stream the generation:

```python
from fastapi.responses import StreamingResponse

async def generate_stream(query: str, context: str):
    """Stream tokens as they're generated."""
    prompt = ANSWER_TEMPLATE.format(context=context, question=query)

    def event_stream():
        for chunk in ollama.generate(
            model="mistral:latest",
            prompt=prompt,
            stream=True
        ):
            yield chunk['response']

    return StreamingResponse(event_stream(), media_type="text/plain")

@app.get("/ask/stream")
async def ask_stream(query: str, user_name: str):
    results = collection.query(
        query_texts=[query],
        n_results=3,
        where={"user_name": user_name}
    )
    context = "\n\n".join(results['documents'][0])
    return await generate_stream(query, context)
```

## Performance Notes

- **Embedding latency:** ~100-500ms per chunk (depends on model size). Batch where possible.
- **Similarity search:** O(n) on small collections. Use HNSW index (ChromaDB default).
- **Memory:** Nomic embeddings ~1.5GB, Mistral 7B ~16GB. Scale horizontally if needed.
- **Cold start:** First query is slow (~30s). Warm cache with /health.

## Security Considerations

- Always filter by `user_name` or similar tenant ID.
- Validate all inputs (sanitize query strings).
- Rate-limit `/ask` and `/documents` endpoints.
- Log access for audit trails.
- Consider encryption at rest for sensitive documents.
