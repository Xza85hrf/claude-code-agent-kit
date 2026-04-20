# Secure Coding Patterns

> Reusable patterns for writing secure code across common scenarios.

---

## Input Validation Patterns

### Pattern: Allowlist Validation

**Use when:** Validating any input with a known set of valid values.

```typescript
// Define allowed values as constants
const ALLOWED_SORT_FIELDS = ['name', 'date', 'price'] as const;
type SortField = typeof ALLOWED_SORT_FIELDS[number];

function validateSortField(input: string): SortField {
  if (!ALLOWED_SORT_FIELDS.includes(input as SortField)) {
    throw new ValidationError(`Invalid sort field: ${input}`);
  }
  return input as SortField;
}

// Usage
const sortField = validateSortField(req.query.sort); // Safe
```

### Pattern: Schema Validation

**Use when:** Validating complex input structures.

```typescript
import { z } from 'zod';

// Define schema
const UserInputSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100),
  age: z.number().int().min(0).max(150).optional(),
});

type UserInput = z.infer<typeof UserInputSchema>;

// Validate
function validateUserInput(data: unknown): UserInput {
  return UserInputSchema.parse(data); // Throws on invalid
}
```

### Pattern: Sanitize Then Validate

**Use when:** Input might contain dangerous characters that need removal.

```typescript
function sanitizeAndValidateUsername(input: string): string {
  // 1. Normalize unicode
  const normalized = input.normalize('NFC');

  // 2. Remove dangerous characters
  const sanitized = normalized.replace(/[<>"'&]/g, '');

  // 3. Validate format
  if (!/^[a-zA-Z0-9_-]{3,30}$/.test(sanitized)) {
    throw new ValidationError('Invalid username format');
  }

  return sanitized;
}
```

---

## Output Encoding Patterns

### Pattern: Context-Aware Encoding

**Use when:** Outputting user data to different contexts.

```typescript
// HTML context
function encodeForHtml(input: string): string {
  const map: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
  };
  return input.replace(/[&<>"']/g, (char) => map[char]);
}

// URL parameter context
function encodeForUrl(input: string): string {
  return encodeURIComponent(input);
}

// JavaScript string context
function encodeForJs(input: string): string {
  return JSON.stringify(input);
}

// Usage depends on OUTPUT context, not input source
const htmlSafe = encodeForHtml(userInput);
const urlSafe = encodeForUrl(userInput);
const jsSafe = encodeForJs(userInput);
```

### Pattern: Safe HTML Rendering with DOMPurify

**Use when:** You must render user HTML content (ALWAYS use sanitization).

```typescript
import DOMPurify from 'dompurify';

// Configure DOMPurify with strict allowlist
const purifyConfig = {
  ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
  ALLOWED_ATTR: ['href', 'title'],
  ALLOW_DATA_ATTR: false,
};

function sanitizeHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, purifyConfig);
}

// Safe usage - content is sanitized before rendering
const cleanHtml = sanitizeHtml(userProvidedHtml);
element.textContent = ''; // Clear first
element.insertAdjacentHTML('beforeend', cleanHtml);
```

---

## Authentication Patterns

### Pattern: Secure Password Handling

**Use when:** Storing or verifying passwords.

```typescript
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12;
const MIN_PASSWORD_LENGTH = 12;

async function hashPassword(password: string): Promise<string> {
  validatePasswordStrength(password);
  return bcrypt.hash(password, SALT_ROUNDS);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  // bcrypt.compare is timing-safe
  return bcrypt.compare(password, hash);
}

function validatePasswordStrength(password: string): void {
  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new ValidationError('Password too short');
  }
  // Add more checks: uppercase, lowercase, numbers, symbols
}
```

### Pattern: Secure Session Management

**Use when:** Creating and managing user sessions.

```typescript
import crypto from 'crypto';

interface Session {
  id: string;
  userId: string;
  createdAt: Date;
  expiresAt: Date;
  ipAddress: string;
  userAgent: string;
}

function createSession(userId: string, req: Request): Session {
  const now = new Date();
  return {
    id: crypto.randomBytes(32).toString('hex'),
    userId,
    createdAt: now,
    expiresAt: new Date(now.getTime() + 3600000), // 1 hour
    ipAddress: req.ip,
    userAgent: req.headers['user-agent'] || '',
  };
}

function validateSession(session: Session, req: Request): boolean {
  const now = new Date();

  // Check expiration
  if (now > session.expiresAt) return false;

  // Optional: Check IP binding (can break for mobile users)
  // if (session.ipAddress !== req.ip) return false;

  return true;
}
```

### Pattern: Rate Limiting

**Use when:** Protecting against brute force attacks.

```typescript
import { RateLimiter } from 'rate-limiter-flexible';

// Create limiter for login attempts
const loginLimiter = new RateLimiter({
  points: 5,        // 5 attempts
  duration: 60 * 15, // per 15 minutes
  blockDuration: 60 * 60, // block for 1 hour if exceeded
});

async function handleLogin(req: Request): Promise<Response> {
  const key = `login:${req.ip}:${req.body.email}`;

  try {
    await loginLimiter.consume(key);
  } catch (error) {
    return new Response('Too many attempts', { status: 429 });
  }

  // Proceed with login...
}
```

---

## Authorization Patterns

### Pattern: Resource Ownership Check

**Use when:** Accessing user-owned resources.

```typescript
async function getResource(
  userId: string,
  resourceId: string
): Promise<Resource> {
  const resource = await db.resources.findById(resourceId);

  if (!resource) {
    // Don't reveal existence to unauthorized users
    throw new NotFoundError('Resource not found');
  }

  if (resource.ownerId !== userId) {
    // Could also throw NotFoundError to hide existence
    throw new ForbiddenError('Access denied');
  }

  return resource;
}
```

### Pattern: Role-Based Access Control

**Use when:** Enforcing permissions based on user roles.

```typescript
type Permission = 'read' | 'write' | 'delete' | 'admin';
type Role = 'viewer' | 'editor' | 'admin';

const rolePermissions: Record<Role, Set<Permission>> = {
  viewer: new Set(['read']),
  editor: new Set(['read', 'write']),
  admin: new Set(['read', 'write', 'delete', 'admin']),
};

function hasPermission(user: User, permission: Permission): boolean {
  const permissions = rolePermissions[user.role];
  return permissions?.has(permission) ?? false;
}

function requirePermission(permission: Permission) {
  return function (req: Request, res: Response, next: Function) {
    if (!hasPermission(req.user, permission)) {
      return res.status(403).json({ error: 'Forbidden' });
    }
    next();
  };
}

// Usage
app.delete('/resource/:id', requirePermission('delete'), handleDelete);
```

---

## Data Protection Patterns

### Pattern: Encryption at Rest

**Use when:** Storing sensitive data.

```typescript
import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';

interface EncryptedData {
  iv: string;
  authTag: string;
  data: string;
}

function encrypt(plaintext: string, key: Buffer): EncryptedData {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

  let encrypted = cipher.update(plaintext, 'utf8', 'hex');
  encrypted += cipher.final('hex');

  return {
    iv: iv.toString('hex'),
    authTag: cipher.getAuthTag().toString('hex'),
    data: encrypted,
  };
}

function decrypt(encrypted: EncryptedData, key: Buffer): string {
  const decipher = crypto.createDecipheriv(
    ALGORITHM,
    key,
    Buffer.from(encrypted.iv, 'hex')
  );
  decipher.setAuthTag(Buffer.from(encrypted.authTag, 'hex'));

  let decrypted = decipher.update(encrypted.data, 'hex', 'utf8');
  decrypted += decipher.final('utf8');

  return decrypted;
}
```

### Pattern: Secure Secrets Management

**Use when:** Accessing secrets in application code.

```typescript
// Load from environment (never hardcode)
function getSecret(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new ConfigError(`Missing required secret: ${name}`);
  }
  return value;
}

// Or use a secret manager
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';

async function getSecretFromManager(secretId: string): Promise<string> {
  const client = new SecretManagerServiceClient();
  const [version] = await client.accessSecretVersion({
    name: `projects/my-project/secrets/${secretId}/versions/latest`,
  });
  return version.payload?.data?.toString() ?? '';
}
```

---

## Error Handling Patterns

### Pattern: Safe Error Responses

**Use when:** Returning errors to clients.

```typescript
// Custom error classes with safe messages
class AppError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public publicMessage: string // Safe for client
  ) {
    super(message);
  }
}

class NotFoundError extends AppError {
  constructor(resource: string) {
    super(
      `${resource} not found`, // Internal logging
      404,
      'Resource not found' // Safe public message
    );
  }
}

// Error handler middleware
function errorHandler(err: Error, req: Request, res: Response) {
  // Log full error internally
  logger.error({
    error: err.message,
    stack: err.stack,
    requestId: req.id,
  });

  // Return safe message to client
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      error: err.publicMessage,
    });
  }

  // Generic error for unexpected issues
  return res.status(500).json({
    error: 'An unexpected error occurred',
  });
}
```

---

## Logging Patterns

### Pattern: Security Event Logging

**Use when:** Recording security-relevant events.

```typescript
interface SecurityEvent {
  timestamp: string;
  eventType: string;
  severity: 'info' | 'warning' | 'critical';
  userId?: string;
  ipAddress: string;
  resource?: string;
  action: string;
  outcome: 'success' | 'failure';
  metadata: Record<string, unknown>;
}

function logSecurityEvent(event: Omit<SecurityEvent, 'timestamp'>): void {
  const fullEvent: SecurityEvent = {
    ...event,
    timestamp: new Date().toISOString(),
  };

  // Never log sensitive data
  delete fullEvent.metadata['password'];
  delete fullEvent.metadata['token'];
  delete fullEvent.metadata['creditCard'];

  securityLogger.log(fullEvent);
}

// Usage
logSecurityEvent({
  eventType: 'AUTH_FAILURE',
  severity: 'warning',
  ipAddress: req.ip,
  action: 'login',
  outcome: 'failure',
  metadata: { email: req.body.email, reason: 'invalid_password' },
});
```

---

## Quick Reference

| Scenario | Pattern | Key Point |
|----------|---------|-----------|
| Validating options | Allowlist | Define valid values explicitly |
| Complex input | Schema validation | Use Zod, Joi, or similar |
| HTML output | Context encoding | Encode for output context |
| User HTML | DOMPurify | Sanitize with strict config |
| Passwords | bcrypt/argon2 | Cost factor >= 12 |
| Sessions | Crypto random | 32+ bytes of randomness |
| Auth endpoints | Rate limiting | Per IP and per account |
| User resources | Ownership check | Always verify ownership |
| Permissions | RBAC | Deny by default |
| Sensitive data | AES-256-GCM | Unique IV per encryption |
| Secrets | Env vars/managers | Never hardcode |
| Errors | Safe messages | Internal vs public |
| Security events | Structured logging | No sensitive data |
