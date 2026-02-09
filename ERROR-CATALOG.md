# Error Catalog Template

> Document common errors, their causes, and proven solutions.
> Add project-specific errors as you encounter them.

---

## How to Use This Catalog

1. **When you encounter an error:** Search this file first
2. **When you solve a new error:** Add it to the catalog
3. **Include:** Error message, cause, solution, prevention

---

## Error Entry Template

```markdown
### ERROR: [Error message or type]

**Symptoms:**
- What the user sees
- What logs show

**Cause:**
Root cause explanation

**Solution:**
Step-by-step fix

**Prevention:**
How to avoid in future

**Related:**
Links to docs, similar errors
```

---

## JavaScript/TypeScript Errors

### ERROR: Cannot find module 'X'

**Symptoms:**
- Build fails with "Cannot find module 'package-name'"
- TypeScript shows import error

**Cause:**
- Package not installed
- Wrong import path
- TypeScript types not installed

**Solution:**
```bash
# Check if package exists
npm ls package-name

# Install if missing
npm install package-name

# For TypeScript types
npm install -D @types/package-name
```

**Prevention:**
- Run `npm install` after pulling changes
- Check package.json before importing

---

### ERROR: 'X' is not a function

**Symptoms:**
- Runtime error: "TypeError: X is not a function"

**Cause:**
- Importing wrong export (default vs named)
- Module not properly exported
- Circular dependency

**Solution:**
```typescript
// Check export type
// Named export
import { functionName } from './module'

// Default export
import functionName from './module'

// Check the module's exports
export const myFunction = () => {}  // named
export default myFunction           // default
```

**Prevention:**
- Consistent export patterns
- Use TypeScript for type checking

---

### ERROR: React Hook called conditionally

**Symptoms:**
- "React Hook 'useX' is called conditionally"

**Cause:**
- Hook inside if statement, loop, or after early return

**Solution:**
```typescript
// Bad
function Component({ show }) {
  if (!show) return null
  const [state, setState] = useState()  // Error!
}

// Good
function Component({ show }) {
  const [state, setState] = useState()
  if (!show) return null
}
```

**Prevention:**
- All hooks at top of component
- ESLint rules-of-hooks plugin

---

### ERROR: Objects are not valid as React child

**Symptoms:**
- "Objects are not valid as a React child"

**Cause:**
- Rendering an object directly in JSX
- Async function returning in JSX

**Solution:**
```tsx
// Bad
<div>{user}</div>           // user is object
<div>{fetchData()}</div>    // returns Promise

// Good
<div>{user.name}</div>
<div>{JSON.stringify(user)}</div>
```

**Prevention:**
- Always access specific properties
- TypeScript helps catch this

---

## Python Errors

### ERROR: ModuleNotFoundError

**Symptoms:**
- "ModuleNotFoundError: No module named 'X'"

**Cause:**
- Package not installed
- Wrong virtual environment
- Incorrect PYTHONPATH

**Solution:**
```bash
# Check if in right venv
which python

# Activate venv
source venv/bin/activate  # Linux/Mac
.\venv\Scripts\activate   # Windows

# Install package
pip install package-name
```

**Prevention:**
- Always work in virtual environment
- Maintain requirements.txt

---

### ERROR: IndentationError

**Symptoms:**
- "IndentationError: unexpected indent"
- "IndentationError: expected an indented block"

**Cause:**
- Mixed tabs and spaces
- Inconsistent indentation

**Solution:**
```bash
# Convert tabs to spaces
# In VS Code: Ctrl+Shift+P → "Convert Indentation to Spaces"

# Fix with autopep8
pip install autopep8
autopep8 --in-place --aggressive file.py
```

**Prevention:**
- Use editor with consistent settings
- Configure .editorconfig

---

### ERROR: TypeError: 'NoneType' object is not subscriptable

**Symptoms:**
- Crashes when accessing index or key on None

**Cause:**
- Function returned None unexpectedly
- Missing null check

**Solution:**
```python
# Bad
result = get_user(id)
print(result['name'])  # Crashes if result is None

# Good
result = get_user(id)
if result:
    print(result['name'])

# Or with default
result = get_user(id) or {}
print(result.get('name', 'Unknown'))
```

**Prevention:**
- Always check for None before accessing
- Use type hints and mypy

---

## Database Errors

### ERROR: Connection refused

**Symptoms:**
- "Connection refused" to database

**Cause:**
- Database not running
- Wrong port/host
- Firewall blocking

**Solution:**
```bash
# Check if database is running
# PostgreSQL
pg_isready -h localhost -p 5432

# Start if not running
sudo systemctl start postgresql

# Check port
netstat -an | grep 5432
```

**Prevention:**
- Health check in application startup
- Connection retry with backoff

---

### ERROR: Relation does not exist

**Symptoms:**
- "relation 'table_name' does not exist"

**Cause:**
- Table not created (missing migration)
- Wrong database selected
- Case sensitivity issue

**Solution:**
```bash
# Check what tables exist
\dt  # In psql

# Run migrations
alembic upgrade head  # Alembic
npx prisma migrate dev  # Prisma

# Check database name
\c  # In psql shows current database
```

**Prevention:**
- Automated migrations in CI/CD
- Database seeding scripts

---

## Git Errors

### ERROR: Merge conflict

**Symptoms:**
- Git reports conflict markers in files

**Solution:**
```bash
# See conflicting files
git status

# Edit files to resolve (remove conflict markers)
# <<<<<<< HEAD
# your changes
# =======
# their changes
# >>>>>>> branch

# Mark as resolved
git add <file>

# Complete merge
git commit
```

**Prevention:**
- Pull before starting work
- Small, frequent commits
- Communicate about shared files

---

### ERROR: Detached HEAD

**Symptoms:**
- "You are in 'detached HEAD' state"

**Cause:**
- Checked out a commit instead of branch

**Solution:**
```bash
# Create branch from current state
git checkout -b new-branch-name

# Or return to a branch
git checkout main
```

**Prevention:**
- Always checkout branches, not commits
- Use `git switch` instead of `git checkout`

---

## Network Errors

### ERROR: CORS error

**Symptoms:**
- "Access-Control-Allow-Origin" error in browser

**Cause:**
- Backend not sending CORS headers
- Mismatched origins

**Solution:**
```python
# FastAPI
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)
```

```javascript
// Express
const cors = require('cors')
app.use(cors({ origin: 'http://localhost:3000' }))
```

**Prevention:**
- Configure CORS in development setup
- Understand CORS before deployment

---

### ERROR: 401 Unauthorized

**Symptoms:**
- API returns 401

**Cause:**
- Missing authentication token
- Expired token
- Wrong token format

**Solution:**
```javascript
// Check token is being sent
fetch('/api/data', {
  headers: {
    'Authorization': `Bearer ${token}`  // Note: Bearer prefix
  }
})

// Check token is valid
jwt.verify(token, secret)
```

**Prevention:**
- Token refresh mechanism
- Clear error messages for auth issues

---

## Build/Deploy Errors

### ERROR: Build fails with memory error

**Symptoms:**
- "JavaScript heap out of memory"

**Cause:**
- Build process exceeds Node memory limit

**Solution:**
```bash
# Increase memory
NODE_OPTIONS="--max-old-space-size=4096" npm run build

# Or in package.json
"scripts": {
  "build": "NODE_OPTIONS='--max-old-space-size=4096' next build"
}
```

**Prevention:**
- Monitor build memory usage
- Split large bundles

---

### ERROR: Port already in use

**Symptoms:**
- "EADDRINUSE: address already in use"

**Cause:**
- Another process using the port

**Solution:**
```bash
# Find process
lsof -i :3000  # Mac/Linux
netstat -ano | findstr :3000  # Windows

# Kill process
kill -9 <PID>  # Mac/Linux
taskkill /PID <PID> /F  # Windows
```

**Prevention:**
- Use different ports for different projects
- Clean shutdown of dev servers

---

## NPM/Node Errors

### ERROR: ERESOLVE - Peer Dependency Conflict

**Symptoms:**
- `npm error ERESOLVE could not resolve`
- `npm error Could not resolve dependency: peerOptional X from Y`
- Build fails on Vercel/CI but works locally

**Example:**
```
npm error peerOptional @neondatabase/serverless@">=0.10.0" from drizzle-orm@0.36.4
npm error Found: @neondatabase/serverless@0.9.5
```

**Cause:**
- A dependency updated its peer dependency requirements
- Your package.json has an older version of the peer dependency
- npm strict mode (CI) fails while local npm with existing node_modules might work

**Solution:**
```bash
# 1. Check which version is needed
npm ls @neondatabase/serverless drizzle-orm

# 2. Update package.json to meet peer requirement
# Change "@neondatabase/serverless": "^0.9.5" to "^0.10.1"

# 3. Reinstall and commit
npm install
git add package.json package-lock.json
git commit -m "fix: upgrade dependency to resolve peer conflict"
```

**Prevention:**
- Always commit `package-lock.json` for reproducible builds
- Run `npm ls` before pushing to check for peer warnings
- Keep dependencies current with `npm outdated`
- Don't use `--legacy-peer-deps` as a permanent fix (masks real issues)

**Related:**
- [npm peer dependencies docs](https://docs.npmjs.com/cli/v10/configuring-npm/package-json#peerdependencies)

---

## Add Your Project-Specific Errors Below

<!--
Add errors specific to your project as you encounter them.
Use the template format for consistency.
-->

---

*Part of the Agent Enhancement Kit for world-class coding agents.*
