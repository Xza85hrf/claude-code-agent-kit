---
name: programmatic-tool-calling
description: Build Claude API agents using Programmatic Tool Calling (PTC) to reduce tokens 85%+ and eliminate model round-trips.
argument-hint: "Design a PTC agent that queries 50 customer records, filters by revenue threshold, and returns only the top 10"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
model: inherit
department: engineering
references:
  - references/ptc-examples.md
thinking-level: medium
---

# Programmatic Tool Calling (PTC)

Claude writes Python code that calls your tools as functions in a sandbox — eliminating round-trips and keeping large data out of context.

## When to Use
- 3+ sequential tool calls
- Large results (100s-1000s records), only summaries needed
- Batch operations across N entities
- Data filtering/aggregation before reasoning
- Optimizing API costs

## Architecture: Traditional vs PTC

| Aspect | Traditional | PTC |
|--------|-------------|-----|
| Model calls | N round-trips | 1 invocation |
| Cost | N × (input + output) + all results in context | 1 × (input + output) + only stdout |
| Token savings | — | 85%+ typical |

## Core Setup

### 1. Enable Code Execution + PTC on Tools

```python
tools = [
    # The code execution tool (required)
    {"type": "code_execution_20260120", "name": "code_execution"},

    # Your tools with allowed_callers
    {
        "name": "query_database",
        "description": "Execute SQL query. Returns JSON array of row objects with fields: id (int), name (str), revenue (float), region (str).",
        "input_schema": {
            "type": "object",
            "properties": {
                "sql": {"type": "string", "description": "SQL SELECT query"}
            },
            "required": ["sql"],
        },
        "allowed_callers": ["code_execution_20260120"],
    },
]
```

**Critical rules:**
- Choose ONE caller: `["direct"]` OR `["code_execution_20260120"]` (not both)
- Document output format (JSON structure, field types)
- Return structured JSON for programmatic processing

### 2. Agent Loop with Container Reuse

```python
import anthropic

client = anthropic.Anthropic()

def run_ptc_agent(user_message: str, tools: list) -> str:
    messages = [{"role": "user", "content": user_message}]
    container_id = None

    while True:
        kwargs = {
            "model": "claude-sonnet-4-6",
            "max_tokens": 4096,
            "tools": tools,
            "messages": messages,
        }
        if container_id:
            kwargs["container"] = container_id

        response = client.messages.create(**kwargs)

        # Track container for stateful execution
        if hasattr(response, "container") and response.container:
            container_id = response.container.id

        if response.stop_reason == "end_turn":
            return next(
                (b.text for b in response.content if hasattr(b, "text")), ""
            )

        if response.stop_reason == "tool_use":
            messages.append({"role": "assistant", "content": response.content})

            # Execute all tool calls, return results
            # IMPORTANT: only tool_result blocks — no text content
            tool_results = []
            for block in response.content:
                if hasattr(block, "name") and block.type == "tool_use":
                    result = execute_tool(block.name, block.input)
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": json.dumps(result) if isinstance(result, (dict, list)) else str(result),
                    })

            messages.append({"role": "user", "content": tool_results})
```

### 3. Identify Caller Type

```python
for block in response.content:
    if block.type == "tool_use":
        if block.caller["type"] == "code_execution_20260120":
            print(f"PTC call: {block.name}")  # Called from code
        elif block.caller["type"] == "direct":
            print(f"Direct call: {block.name}")  # Traditional
```

## Tool Design for PTC

Tools called from code execution need different design than traditional tools:

| Aspect | Traditional Tool | PTC-Optimized Tool |
|--------|-----------------|-------------------|
| **Output** | Human-readable text OK | Structured JSON required |
| **Description** | Brief | Detailed output schema (field names, types, structure) |
| **Response size** | Can be large (model reads it) | Can be large (code filters it) |
| **Side effects** | OK with oversight | Must be safe for loops/batches |
| **Idempotency** | Nice to have | Important (may be retried on timeout) |

**Output description example:**
```python
{
    "name": "get_expenses",
    "description": "Returns expense line items as JSON array. Each item: {id: string, employee_id: string, amount: float, category: string (travel|meals|supplies|equipment), status: string (approved|pending|rejected), date: string (ISO 8601)}",
    # ...
}
```

## Advanced Patterns

| Pattern | Example |
|---------|---------|
| Batch processing | Loop over N entities, aggregate results |
| Early termination | Break when condition met (find 1st healthy endpoint) |
| Data filtering | Reduce 1000s records to key findings (errors only) |
| Conditional selection | Choose tool based on data size/type |

## Constraints to Know

| Constraint | Impact |
|------------|--------|
| `strict: true` tools | Cannot be called programmatically |
| `tool_choice` | Cannot force PTC for a specific tool |
| `disable_parallel_tool_use` | Incompatible with PTC |
| MCP connector tools | Not yet supported (planned) |
| Container timeout | ~4.5 min inactivity — respond to tool calls promptly |
| Response format | When replying to programmatic tool calls: ONLY `tool_result` blocks, NO text |
| ZDR | PTC is not covered by Zero Data Retention |

## Container Lifecycle

```
Request 1 → Container created (container_id returned)
Request 2 → Pass container_id → State preserved (variables, files)
...
~4.5 min idle → Container expires
```

Monitor `response.container.expires_at`. If your tool execution is slow, the container may expire and Claude retries the call.

## Performance Benchmarks

| Metric | Traditional | PTC | Improvement |
|--------|-------------|-----|-------------|
| Tokens (20-employee budget check) | 110,473 | 15,919 | **-85.6%** |
| API calls | 4 | 4 | Same |
| Latency | 35.38s | 34.88s | ~Same |

Latency improvements scale with sequential tool call count — PTC shines when traditional approach needs 10-50 model round-trips.

## Decision Checklist

Use PTC if:
- 3+ sequential tool calls
- Large intermediate results (>1KB)
- Batch operations (loop in code, not N calls)

Use traditional if:
- Need human oversight per call
- Single simple call
- Dangerous side effects

## Error Handling

| Scenario | Action |
|----------|--------|
| Container timeout | Respond before `expires_at` |
| Tool error | Return error string in tool_result |
| Code error | Claude sees stderr, writes recovery |

```python
{"type": "tool_result", "tool_use_id": "...", "content": "Error: Query timeout after 30s"}
```
