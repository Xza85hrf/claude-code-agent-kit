# OWASP Top 10 - Detailed Reference

> The OWASP Top 10 represents the most critical security risks to web applications.
> Updated for 2021 classification with modern attack patterns.

---

## A01:2021 - Broken Access Control

**What it is:** Failures in enforcing access policies, allowing users to act outside their intended permissions.

**Common vulnerabilities:**
- Missing authorization checks on endpoints
- IDOR (Insecure Direct Object References)
- Bypassing access control via URL/parameter manipulation
- Elevation of privilege (user to admin)
- CORS misconfiguration allowing unauthorized API access

**Prevention:**

```
DENY BY DEFAULT
├── Every endpoint requires explicit authorization
├── Check ownership for every resource access
├── Server-side enforcement (never client-only)
├── Disable directory listing
├── Log access control failures, alert on patterns
└── Rate limit API access to minimize automated abuse
```

**Code pattern:**
```typescript
// Always verify ownership/permission
async function getResource(user: User, resourceId: string) {
  const resource = await db.resources.findById(resourceId);

  if (!resource) {
    throw new NotFoundError(); // Don't reveal existence
  }

  if (!canAccess(user, resource)) {
    throw new ForbiddenError();
  }

  return resource;
}
```

---

## A02:2021 - Cryptographic Failures

**What it is:** Failures related to cryptography that often lead to sensitive data exposure.

**Common vulnerabilities:**
- Transmitting data in clear text (HTTP, SMTP, FTP)
- Using deprecated/weak cryptographic algorithms
- Using default or weak keys
- Not enforcing encryption (missing HSTS)
- Storing passwords with reversible encryption or weak hashes

**Prevention:**

```
CRYPTO CHECKLIST
├── TLS 1.2+ for all data in transit
├── HSTS headers with long max-age
├── Strong ciphers only (disable weak suites)
├── bcrypt/argon2/scrypt for password hashing
├── AES-256-GCM for data at rest
├── Unique IVs/nonces for each encryption
├── Secure key management (HSM, secret managers)
└── No sensitive data in logs, errors, or URLs
```

**Secure password hashing:**
```typescript
import bcrypt from 'bcrypt';

const SALT_ROUNDS = 12; // Adjust for your security needs

async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}
```

---

## A03:2021 - Injection

**What it is:** User-supplied data sent to an interpreter as part of a command or query.

**Common vulnerabilities:**
- SQL injection
- NoSQL injection
- OS command injection
- LDAP injection
- XPath injection
- Expression Language injection

**Prevention:**

```
INJECTION DEFENSE
├── Use parameterized queries (ALWAYS)
├── Use ORM with bound parameters
├── Input validation (allowlist, type, length)
├── Escape special characters for context
├── Least privilege database accounts
├── Avoid shell commands with user input
└── Use structured APIs instead of raw interpreters
```

**Parameterized queries:**
```typescript
// SQL - PostgreSQL example
const result = await db.query(
  'SELECT * FROM users WHERE email = $1 AND status = $2',
  [email, status]
);

// SQL - MySQL example
const [rows] = await connection.execute(
  'SELECT * FROM users WHERE email = ? AND status = ?',
  [email, status]
);

// MongoDB
const user = await User.findOne({
  email: { $eq: userEmail }  // Explicit operator prevents injection
});
```

---

## A04:2021 - Insecure Design

**What it is:** Risks related to design and architectural flaws.

**Common vulnerabilities:**
- Missing security requirements in design
- No threat modeling performed
- Insecure design patterns
- Insufficient security controls for business logic
- Missing rate limiting on critical functions

**Prevention:**

```
SECURE DESIGN PROCESS
├── Threat modeling during design (STRIDE)
├── Security requirements in user stories
├── Secure design patterns and reference architectures
├── Unit and integration testing for security scenarios
├── Abuse case testing (what can go wrong?)
├── Security review at each sprint
└── Defense in depth (multiple layers)
```

**Design questions to ask:**
- What are the trust boundaries?
- What happens if this component is compromised?
- How do we limit blast radius?
- What can an attacker do with valid credentials?
- How do we detect abuse?

---

## A05:2021 - Security Misconfiguration

**What it is:** Missing or incorrect security configurations.

**Common vulnerabilities:**
- Unnecessary features enabled
- Default accounts/passwords unchanged
- Error handling revealing stack traces
- Missing security headers
- Outdated software with known vulnerabilities
- Insecure cloud storage permissions

**Prevention:**

```
CONFIGURATION HARDENING
├── Minimal installation (no unused features)
├── Review all default configurations
├── Different credentials for each environment
├── Disable detailed error messages in production
├── Set security headers (CSP, X-Frame-Options, etc.)
├── Automated configuration scanning
└── Regular patching process
```

**Essential security headers:**
```
Content-Security-Policy: default-src 'self'; script-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), camera=(), microphone=()
```

---

## A06:2021 - Vulnerable and Outdated Components

**What it is:** Using components with known vulnerabilities.

**Common vulnerabilities:**
- Using unmaintained libraries
- Not tracking component versions
- Not scanning for CVEs
- Using components with known severe vulnerabilities
- Not testing library compatibility after updates

**Prevention:**

```
DEPENDENCY MANAGEMENT
├── Inventory all components and versions
├── Remove unused dependencies
├── Automated vulnerability scanning (Dependabot, Snyk)
├── Subscribe to security advisories
├── Regular update schedule
├── Test updates before deployment
└── Pin versions (but still update regularly)
```

**Scanning commands:**
```bash
# Node.js
npm audit
npm audit fix

# Python
pip-audit
safety check

# General
snyk test
trivy fs .
```

---

## A07:2021 - Identification and Authentication Failures

**What it is:** Failures in confirming user identity, authentication, and session management.

**Common vulnerabilities:**
- Permitting weak passwords
- Credential stuffing (using known leaked credentials)
- Missing/ineffective multi-factor authentication
- Session tokens in URL
- Not invalidating sessions properly
- Missing brute force protection

**Prevention:**

```
AUTH HARDENING
├── Enforce password complexity (12+ chars, mixed)
├── Check against known breached passwords
├── Multi-factor authentication
├── Rate limiting on auth endpoints
├── Account lockout after failures
├── Secure session management
├── Session timeout (idle + absolute)
└── New session ID after login
```

**Session management:**
```typescript
// Generate cryptographically secure session ID
import crypto from 'crypto';

function generateSessionId(): string {
  return crypto.randomBytes(32).toString('hex');
}

// Session configuration
const sessionConfig = {
  secret: process.env.SESSION_SECRET,
  resave: false,
  saveUninitialized: false,
  cookie: {
    secure: true,      // HTTPS only
    httpOnly: true,    // No JavaScript access
    sameSite: 'strict', // CSRF protection
    maxAge: 3600000    // 1 hour
  }
};
```

---

## A08:2021 - Software and Data Integrity Failures

**What it is:** Code and infrastructure that does not protect against integrity violations.

**Common vulnerabilities:**
- Using untrusted CDNs without integrity checks
- Insecure deserialization
- Auto-update without signature verification
- CI/CD pipelines without integrity verification
- Unsigned or unencrypted serialized data

**Prevention:**

```
INTEGRITY CONTROLS
├── Digital signatures for updates and deployments
├── Subresource Integrity (SRI) for CDN assets
├── Signed commits and verified pipelines
├── Repository integrity monitoring
├── Avoid unsafe deserialization
└── Verify source and integrity of all components
```

**SRI for external resources:**
```html
<script
  src="https://cdn.example.com/library.js"
  integrity="sha384-oqVuAfXRKap7fdgcCY5uykM6+R9GqQ8K/uxy9rx7HNQlGYl1kPzQho1wx4JwY8wC"
  crossorigin="anonymous">
</script>
```

---

## A09:2021 - Security Logging and Monitoring Failures

**What it is:** Insufficient logging, detection, monitoring, and active response.

**Common vulnerabilities:**
- Not logging authentication events
- Logs not capturing sufficient detail
- Logs stored only locally
- No alerting on suspicious activity
- No incident response process

**Prevention:**

```
LOGGING REQUIREMENTS
├── Log all auth events (success and failure)
├── Log access control failures
├── Log input validation failures
├── Include context (who, what, when, where)
├── Centralized, tamper-evident logging
├── Automated alerting on anomalies
├── Regular log review process
└── NEVER log sensitive data (passwords, tokens, PII)
```

**What to log:**
```typescript
interface SecurityEvent {
  timestamp: string;
  eventType: 'AUTH_SUCCESS' | 'AUTH_FAILURE' | 'ACCESS_DENIED' | 'VALIDATION_FAILURE';
  userId?: string;
  ipAddress: string;
  userAgent: string;
  resource: string;
  action: string;
  outcome: 'success' | 'failure';
  details: Record<string, unknown>; // Never include sensitive data
}
```

---

## A10:2021 - Server-Side Request Forgery (SSRF)

**What it is:** Application fetching remote resources without validating user-supplied URLs.

**Common vulnerabilities:**
- Fetching URLs provided by users
- Accessing cloud metadata services
- Internal port scanning via application
- Reading local files via file:// protocol
- Bypassing firewalls for internal requests

**Prevention:**

```
SSRF DEFENSE
├── Allowlist of permitted domains/IPs
├── Block private IP ranges (10.x, 172.16.x, 192.168.x)
├── Block localhost and loopback
├── Block cloud metadata IPs (169.254.169.254)
├── Disable unnecessary URL schemes
├── Don't return raw response bodies
└── Network segmentation for internal services
```

**URL validation:**
```typescript
import { URL } from 'url';

const ALLOWED_DOMAINS = new Set(['api.trusted.com', 'cdn.trusted.com']);
const BLOCKED_IPS = /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|0\.|169\.254\.)/;

function validateUrl(urlString: string): URL {
  const url = new URL(urlString);

  // Only allow HTTPS
  if (url.protocol !== 'https:') {
    throw new SecurityError('Only HTTPS URLs allowed');
  }

  // Check against allowlist
  if (!ALLOWED_DOMAINS.has(url.hostname)) {
    throw new SecurityError('Domain not allowed');
  }

  // Resolve and check IP (simplified)
  // In production, resolve DNS and check the actual IP

  return url;
}
```

---

## Quick Reference Matrix

| Risk | Primary Defense | Secondary Defense |
|------|-----------------|-------------------|
| A01 Broken Access Control | Deny by default, ownership checks | Audit logging |
| A02 Cryptographic Failures | TLS, strong algorithms | Key management |
| A03 Injection | Parameterized queries | Input validation |
| A04 Insecure Design | Threat modeling | Defense in depth |
| A05 Misconfiguration | Hardening guides | Automated scanning |
| A06 Vulnerable Components | Dependency scanning | Regular updates |
| A07 Auth Failures | MFA, rate limiting | Session management |
| A08 Integrity Failures | Signatures, SRI | Verified pipelines |
| A09 Logging Failures | Centralized logging | Alerting |
| A10 SSRF | URL allowlisting | Network segmentation |

---

*Reference: https://owasp.org/Top10/*
