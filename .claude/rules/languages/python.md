---
paths: ["**/*.py", "**/*.pyi"]
---

# Python Rules (extends common rules)

## Type Hints
- Type hints on all public functions
- Use `from __future__ import annotations` for forward refs
- Prefer `Protocol` over ABC for structural typing
- Use `TypedDict` for structured dicts, `dataclass` for data objects

## Patterns
- f-strings for formatting (not `.format()` or `%`)
- `pathlib.Path` over `os.path`
- Context managers for resource management
- `subprocess.run(..., shell=False)` — never `shell=True` with user input

## Anti-Patterns
- No `import *` — explicit imports only
- No mutable default arguments (`def f(x=[])`)
- No bare `except:` — always specify exception type
- Use `subprocess.run()` instead of deprecated shell execution functions
