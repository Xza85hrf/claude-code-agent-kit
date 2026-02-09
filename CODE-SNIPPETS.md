# Code Snippets Library

> Reusable patterns and templates for common implementations.
> Add project-specific patterns as you develop them.

---

## How to Use This Library

1. **Before implementing:** Check if a pattern exists
2. **After implementing:** Add reusable patterns here
3. **Customize:** Adapt snippets to project conventions

---

## React/TypeScript Patterns

### Basic Component with Props

```tsx
interface UserCardProps {
  user: User
  onEdit?: (user: User) => void
  className?: string
}

export function UserCard({ user, onEdit, className }: UserCardProps) {
  return (
    <div className={`user-card ${className || ''}`}>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
      {onEdit && (
        <button onClick={() => onEdit(user)}>Edit</button>
      )}
    </div>
  )
}
```

### Custom Hook with State

```tsx
interface UseToggleReturn {
  isOn: boolean
  toggle: () => void
  setOn: () => void
  setOff: () => void
}

export function useToggle(initial = false): UseToggleReturn {
  const [isOn, setIsOn] = useState(initial)

  const toggle = useCallback(() => setIsOn(prev => !prev), [])
  const setOn = useCallback(() => setIsOn(true), [])
  const setOff = useCallback(() => setIsOn(false), [])

  return { isOn, toggle, setOn, setOff }
}
```

### Data Fetching Hook

```tsx
interface UseFetchResult<T> {
  data: T | null
  loading: boolean
  error: Error | null
  refetch: () => void
}

export function useFetch<T>(url: string): UseFetchResult<T> {
  const [data, setData] = useState<T | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<Error | null>(null)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const response = await fetch(url)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const json = await response.json()
      setData(json)
    } catch (e) {
      setError(e instanceof Error ? e : new Error('Unknown error'))
    } finally {
      setLoading(false)
    }
  }, [url])

  useEffect(() => {
    fetchData()
  }, [fetchData])

  return { data, loading, error, refetch: fetchData }
}
```

### Modal Component

```tsx
interface ModalProps {
  isOpen: boolean
  onClose: () => void
  title: string
  children: React.ReactNode
}

export function Modal({ isOpen, onClose, title, children }: ModalProps) {
  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold">{title}</h2>
          <button onClick={onClose} className="text-gray-500 hover:text-gray-700">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="p-4">
          {children}
        </div>
      </div>
    </div>
  )
}
```

### Form with Validation

```tsx
interface FormData {
  email: string
  password: string
}

export function LoginForm({ onSubmit }: { onSubmit: (data: FormData) => void }) {
  const [formData, setFormData] = useState<FormData>({ email: '', password: '' })
  const [errors, setErrors] = useState<Partial<FormData>>({})

  const validate = (): boolean => {
    const newErrors: Partial<FormData> = {}

    if (!formData.email) {
      newErrors.email = 'Email is required'
    } else if (!/\S+@\S+\.\S+/.test(formData.email)) {
      newErrors.email = 'Invalid email format'
    }

    if (!formData.password) {
      newErrors.password = 'Password is required'
    } else if (formData.password.length < 8) {
      newErrors.password = 'Password must be at least 8 characters'
    }

    setErrors(newErrors)
    return Object.keys(newErrors).length === 0
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (validate()) {
      onSubmit(formData)
    }
  }

  return (
    <form onSubmit={handleSubmit}>
      <div>
        <input
          type="email"
          value={formData.email}
          onChange={e => setFormData(prev => ({ ...prev, email: e.target.value }))}
          placeholder="Email"
        />
        {errors.email && <span className="text-red-500">{errors.email}</span>}
      </div>
      <div>
        <input
          type="password"
          value={formData.password}
          onChange={e => setFormData(prev => ({ ...prev, password: e.target.value }))}
          placeholder="Password"
        />
        {errors.password && <span className="text-red-500">{errors.password}</span>}
      </div>
      <button type="submit">Login</button>
    </form>
  )
}
```

---

## FastAPI/Python Patterns

### Basic CRUD Endpoint

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from uuid import uuid4

router = APIRouter(prefix="/items", tags=["items"])

class Item(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    price: float

class ItemCreate(BaseModel):
    name: str
    description: Optional[str] = None
    price: float

# In-memory storage (replace with database)
items: dict[str, Item] = {}

@router.get("/", response_model=List[Item])
async def list_items():
    return list(items.values())

@router.get("/{item_id}", response_model=Item)
async def get_item(item_id: str):
    if item_id not in items:
        raise HTTPException(status_code=404, detail="Item not found")
    return items[item_id]

@router.post("/", response_model=Item)
async def create_item(item_create: ItemCreate):
    item = Item(id=str(uuid4()), **item_create.model_dump())
    items[item.id] = item
    return item

@router.put("/{item_id}", response_model=Item)
async def update_item(item_id: str, item_update: ItemCreate):
    if item_id not in items:
        raise HTTPException(status_code=404, detail="Item not found")
    items[item_id] = Item(id=item_id, **item_update.model_dump())
    return items[item_id]

@router.delete("/{item_id}")
async def delete_item(item_id: str):
    if item_id not in items:
        raise HTTPException(status_code=404, detail="Item not found")
    del items[item_id]
    return {"status": "deleted"}
```

### Background Task Pattern

```python
from fastapi import BackgroundTasks
import asyncio

async def process_in_background(item_id: str, data: dict):
    """Long-running task executed in background."""
    # Simulate work
    await asyncio.sleep(5)

    # Update status
    processing_status[item_id] = "completed"

@router.post("/{item_id}/process")
async def start_processing(
    item_id: str,
    data: dict,
    background_tasks: BackgroundTasks
):
    processing_status[item_id] = "processing"
    background_tasks.add_task(process_in_background, item_id, data)
    return {"status": "started", "item_id": item_id}

@router.get("/{item_id}/status")
async def get_status(item_id: str):
    status = processing_status.get(item_id, "unknown")
    return {"item_id": item_id, "status": status}
```

### Exception Handler

```python
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

class AppException(Exception):
    def __init__(self, code: str, message: str, status_code: int = 400):
        self.code = code
        self.message = message
        self.status_code = status_code

@app.exception_handler(AppException)
async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "error": {
                "code": exc.code,
                "message": exc.message
            }
        }
    )

# Usage
raise AppException("INVALID_INPUT", "Email format is invalid", 400)
```

### Database Session Pattern (SQLAlchemy)

```python
from sqlalchemy.orm import Session
from contextlib import contextmanager

@contextmanager
def get_db_session():
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

# Usage
with get_db_session() as db:
    user = db.query(User).filter(User.id == user_id).first()
```

---

## Utility Functions

### Debounce (TypeScript)

```typescript
export function debounce<T extends (...args: any[]) => any>(
  func: T,
  wait: number
): (...args: Parameters<T>) => void {
  let timeoutId: ReturnType<typeof setTimeout> | null = null

  return (...args: Parameters<T>) => {
    if (timeoutId) clearTimeout(timeoutId)
    timeoutId = setTimeout(() => func(...args), wait)
  }
}

// Usage
const debouncedSearch = debounce((query: string) => {
  fetchResults(query)
}, 300)
```

### Retry with Backoff (Python)

```python
import asyncio
from typing import TypeVar, Callable, Awaitable

T = TypeVar('T')

async def retry_with_backoff(
    func: Callable[[], Awaitable[T]],
    max_retries: int = 3,
    base_delay: float = 1.0,
    max_delay: float = 30.0
) -> T:
    """Retry async function with exponential backoff."""
    last_exception = None

    for attempt in range(max_retries):
        try:
            return await func()
        except Exception as e:
            last_exception = e
            if attempt < max_retries - 1:
                delay = min(base_delay * (2 ** attempt), max_delay)
                await asyncio.sleep(delay)

    raise last_exception

# Usage
result = await retry_with_backoff(lambda: fetch_external_api())
```

### Date Formatting (TypeScript)

```typescript
export function formatDate(date: Date | string, format: 'short' | 'long' | 'relative' = 'short'): string {
  const d = typeof date === 'string' ? new Date(date) : date

  switch (format) {
    case 'short':
      return d.toLocaleDateString()
    case 'long':
      return d.toLocaleDateString('en-US', {
        weekday: 'long',
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      })
    case 'relative':
      const now = new Date()
      const diff = now.getTime() - d.getTime()
      const days = Math.floor(diff / (1000 * 60 * 60 * 24))

      if (days === 0) return 'Today'
      if (days === 1) return 'Yesterday'
      if (days < 7) return `${days} days ago`
      return d.toLocaleDateString()
  }
}
```

### Safe JSON Parse

```typescript
export function safeJsonParse<T>(json: string, fallback: T): T {
  try {
    return JSON.parse(json) as T
  } catch {
    return fallback
  }
}

// Usage
const config = safeJsonParse<Config>(configString, defaultConfig)
```

---

## Configuration Patterns

### Environment Config (TypeScript)

```typescript
interface Config {
  apiUrl: string
  environment: 'development' | 'staging' | 'production'
  debug: boolean
}

export function getConfig(): Config {
  return {
    apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000',
    environment: (process.env.NODE_ENV as Config['environment']) || 'development',
    debug: process.env.NEXT_PUBLIC_DEBUG === 'true'
  }
}
```

### Environment Config (Python)

```python
from pydantic_settings import BaseSettings
from functools import lru_cache

class Settings(BaseSettings):
    database_url: str = "postgresql://localhost/app"
    secret_key: str
    debug: bool = False
    allowed_origins: list[str] = ["http://localhost:3000"]

    class Config:
        env_file = ".env"

@lru_cache()
def get_settings() -> Settings:
    return Settings()

# Usage
settings = get_settings()
```

---

## Testing Patterns

### React Component Test

```tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { UserCard } from './UserCard'

describe('UserCard', () => {
  const mockUser = { id: '1', name: 'John', email: 'john@example.com' }

  it('renders user information', () => {
    render(<UserCard user={mockUser} />)

    expect(screen.getByText('John')).toBeInTheDocument()
    expect(screen.getByText('john@example.com')).toBeInTheDocument()
  })

  it('calls onEdit when edit button clicked', () => {
    const onEdit = jest.fn()
    render(<UserCard user={mockUser} onEdit={onEdit} />)

    fireEvent.click(screen.getByText('Edit'))

    expect(onEdit).toHaveBeenCalledWith(mockUser)
  })
})
```

### Python API Test

```python
import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_create_item():
    response = client.post("/items/", json={
        "name": "Test Item",
        "price": 9.99
    })
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Test Item"
    assert "id" in data

def test_get_item_not_found():
    response = client.get("/items/nonexistent")
    assert response.status_code == 404
```

---

## Add Your Project-Specific Patterns Below

<!--
Document patterns specific to your project here.
Include:
- Component patterns unique to your app
- API endpoint templates
- Business logic patterns
- Integration patterns
-->

---

*Part of the Agent Enhancement Kit for world-class coding agents.*
