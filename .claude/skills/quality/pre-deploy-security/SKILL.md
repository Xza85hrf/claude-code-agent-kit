---
name: pre-deploy-security
description: "Production deployment security checklist — OWASP ZAP pentesting, Snyk code scanning, database RLS, DDoS protection, rate limiting, DNSSEC, WHOIS proxy. Run before any production deployment."
department: quality
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Edit
  - AskUserQuestion
user-invocable: true
argument-hint: "[project-path]"
thinking-level: high
---

# Pre-Deploy Security Checklist

Production deployments carry irreversible consequences. This skill walks through comprehensive security hardening before ANY production deployment. Each item must pass or have documented exception with risk sign-off.

## Automation vs. Manual Checks

Some checks can be automated (OWASP ZAP, Snyk). Others require manual verification (RLS policies, WHOIS privacy). This skill guides you through both.

---

## 1. Application Security

### 1.1 OWASP Top 10 Manual Review

Use **Skill("security-review")** for comprehensive code-level audit covering:
- A01:2021 – Broken Access Control
- A02:2021 – Cryptographic Failures
- A03:2021 – Injection
- A04:2021 – Insecure Design
- A05:2021 – Security Misconfiguration
- A06:2021 – Vulnerable & Outdated Components
- A07:2021 – Authentication Failures
- A08:2021 – Data Integrity Failures
- A09:2021 – Logging & Monitoring Failures
- A10:2021 – Server-Side Request Forgery (SSRF)

**What to check manually:**
- [ ] Auth flows reviewed for bypasses
- [ ] Input validation on all user-facing endpoints
- [ ] Secrets not in code (check `.env.example` vs `.env`)
- [ ] Sensitive operations require re-authentication (e.g., password changes, account deletion)

### 1.2 OWASP ZAP Automated Scan

```bash
# Install ZAP if not present
which zap-cli || (echo "ZAP not installed. Use Docker instead:" && echo "docker run -t owasp/zap2docker-stable zap-cli quick-scan --self-contained <TARGET_URL>")

# Run quick scan (5-10 min)
TARGET_URL="https://your-app.example.com"
zap-cli quick-scan --self-contained --start-options='-config api.disablekey=true' "$TARGET_URL"

# Or full scan (30+ min)
zap-cli spider "$TARGET_URL"
zap-cli active-scan "$TARGET_URL"
zap-cli report -o zap-report.html -f html
```

**Pass criteria:**
- [ ] No HIGH severity findings in report
- [ ] All MEDIUM findings have mitigation plan documented

### 1.3 Snyk Code & Dependency Scanning

```bash
# Install Snyk
npm install -g snyk

# Authenticate
snyk auth

# Test dependencies for known CVEs
snyk test --severity-threshold=high

# Scan code for security issues
snyk code test --severity=high

# Generate report
snyk test --report --report-title="Pre-Deploy Security"
```

**Pass criteria:**
- [ ] No high-severity CVEs in dependencies (or documented exceptions with remediation timeline)
- [ ] No critical code vulnerabilities
- [ ] All issues triaged and assigned owners if not fixed

### 1.4 AI Application Security (if applicable)

If your app uses LLMs (Claude, GPT, etc.), **use Skill("ai-application-security")** to audit:
- Prompt injection prevention
- Insecure output handling (LLM outputs sanitized before use)
- Access control boundaries (users see only their data)
- Audit logging of all AI interactions

**Pass criteria:**
- [ ] Prompt injection test suite passes
- [ ] LLM outputs validated before rendering or using in system operations
- [ ] No user data leakage between AI requests

---

## 2. Database Security

### 2.1 Row Level Security (RLS)

For PostgreSQL, MySQL 8.0+, or equivalent:

```bash
# PostgreSQL example
psql -h $DB_HOST -d $DB_NAME -c "
  SELECT schemaname, tablename, rowsecurity
  FROM pg_tables
  WHERE schemaname NOT IN ('pg_catalog', 'information_schema');
"

# Expected output: All user-facing tables should have rowsecurity=true
```

**Manual verification:**
- [ ] All user-facing tables (users, posts, comments, etc.) have RLS enabled
- [ ] RLS policies verified by: `\d+ table_name` and check POLICIES
- [ ] Test policy isolation: User A's data invisible to User B
- [ ] Admin role has bypass_rls permission (if needed)

```sql
-- Example RLS Policy (DO NOT just copy — customize for your schema)
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_posts ON posts
  FOR ALL
  USING (auth.uid() = user_id);

CREATE POLICY admin_bypass ON posts
  FOR ALL
  USING (auth.role() = 'admin');
```

**Pass criteria:**
- [ ] RLS verified on ALL user-facing tables
- [ ] RLS policies test-verified with non-admin user login
- [ ] Documented data isolation boundaries

### 2.2 Connection Encryption

```bash
# PostgreSQL
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SHOW ssl;"
# Expected: on or on-negotiated

# MySQL
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD -e "SHOW STATUS LIKE 'Ssl_cipher';"
# Expected: Non-empty (e.g., TLS_AES_256_GCM_SHA384)

# MongoDB
mongosh "$MONGO_URI" --eval "db.adminCommand({serverStatus:1}).security"
```

**Pass criteria:**
- [ ] SSL/TLS enabled (verify with `SHOW ssl` or equiv)
- [ ] Connection strings use `?ssl=true` or `:ssl:`
- [ ] Certificate pinning considered for high-security apps

### 2.3 Backup Verification

```bash
# Check last successful backup
aws s3 ls s3://my-backups/ --recursive --human-readable --summarize | tail -20

# For local backups
ls -lh /backup/ | tail -10

# Test restore (in staging/test environment ONLY)
# 1. Dump production DB to staging
# 2. Verify data integrity (row counts match, no corruption)
# 3. Document restore time (SLA baseline)
```

**Pass criteria:**
- [ ] Most recent backup ≤ 24 hours old
- [ ] Backup is restorable (spot-check row counts in staging)
- [ ] Recovery time documented (RTO)
- [ ] Backup stored in separate region/account

### 2.4 No Exposed Credentials

```bash
# Grep for hardcoded connection strings in code
grep -r "postgresql://" src/ --include="*.ts" --include="*.js" --include="*.py"
grep -r "mysql://" src/ --include="*.ts" --include="*.js" --include="*.py"
grep -r "mongodb://" src/ --include="*.ts" --include="*.js" --include="*.py"

# Should find ZERO results. All connections should use env vars.
if grep -r "://.*:.*@" src/ --include="*.ts" --include="*.js" --include="*.py" | grep -v "localhost" | grep -v "127.0.0.1"; then
  echo "FAIL: Credentials in code"
  exit 1
fi

echo "PASS: No hardcoded DB credentials found"
```

**Pass criteria:**
- [ ] No DB credentials in source code
- [ ] `.env` file is in `.gitignore`
- [ ] `.env.example` shows structure without secrets
- [ ] All DB URIs reference `process.env.DATABASE_URL` or equivalent

---

## 3. Infrastructure Security

### 3.1 DDoS Protection

**Cloudflare (recommended):**
```bash
# Enable DDoS protection
# 1. Verify zone is proxied (orange cloud in DNS)
# 2. Navigate to Cloudflare dashboard → Security → DDoS Protection
# 3. Set to "High" sensitivity (blocks more aggressively)
# 4. Verify bot management is "Super Bot Fight Mode" or higher
```

**AWS/Azure alternatives:**
- AWS Shield (Standard = free, Advanced = $3k/month)
- Azure DDoS Protection (Standard = free, Premium)

**Manual verification:**
```bash
# Test DDoS mitigation response
curl -v -H "X-Forwarded-For: 203.0.113.1,203.0.113.2,203.0.113.3" https://your-app.example.com
# Should still return 200 (DDoS mitigation passes legitimate requests)
```

**Pass criteria:**
- [ ] DDoS protection enabled (Cloudflare, AWS Shield, etc.)
- [ ] Rate limiting configured
- [ ] Documented SLA for mitigation (e.g., "Blocks 99.99% of attacks")

### 3.2 Rate Limiting

Per-IP and per-user rate limiting on APIs.

**Cloudflare approach (easiest):**
```bash
# Dashboard → Security → Rate Limiting
# Create rule: "If requests > 100 per 10 seconds, block for 1 hour"
```

**Code-level (Node.js example):**
```javascript
import rateLimit from "express-rate-limit";

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // 100 requests per windowMs
  message: "Too many requests, please try again later",
  standardHeaders: true, // Return rate limit info in the RateLimit-* headers
  legacyHeaders: false,
});

app.use("/api/", limiter);
```

**Python (FastAPI):**
```python
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.get("/api/endpoint")
@limiter.limit("100/minute")
async def endpoint(request: Request):
    return {"status": "ok"}
```

**Pass criteria:**
- [ ] API endpoints have rate limiting (per-IP minimum)
- [ ] Rate limit headers returned (X-RateLimit-*)
- [ ] Different limits for authenticated vs. unauthenticated (e.g., 100/min auth, 10/min unauth)

### 3.3 Robots.txt & Crawlers

```bash
# Verify robots.txt blocks sensitive routes
cat public/robots.txt
```

**Example:**
```
User-agent: *
Disallow: /admin/
Disallow: /api/internal/
Disallow: /user/*/settings
Allow: /api/public/
```

**Pass criteria:**
- [ ] robots.txt exists and blocks sensitive routes
- [ ] `/admin`, `/user/settings`, internal APIs are disallowed

### 3.4 Bot Fight Mode (Cloudflare)

**Setup:**
```
Cloudflare Dashboard → Security → Bot Management
```

**Options:**
- **Super Bot Fight Mode** (free): Blocks known bots, challenges suspicious traffic
- **Bot Management** (paid): ML-driven bot detection

**Pass criteria:**
- [ ] Super Bot Fight Mode enabled at minimum
- [ ] Legitimate bot traffic (Google, Bing, etc.) allowed
- [ ] Blocked bot traffic logged in Cloudflare analytics

### 3.5 DNSSEC

```bash
# Check DNSSEC status
dig +dnssec your-domain.example.com

# Should show: ad (authenticated data) flag
# Expected: flags: qr rd ra ad;
```

**Setup (for most registrars):**
1. Enable DNSSEC in DNS provider dashboard
2. Wait for propagation (up to 24 hours)
3. Verify with `dig +dnssec`

**Pass criteria:**
- [ ] DNSSEC enabled (verified with `dig +dnssec`)
- [ ] DS records in parent zone

### 3.6 WHOIS Privacy / Domain Proxy

**Check current status:**
```bash
whois your-domain.example.com | grep -i "registrant\|admin\|tech"
```

**If exposed, enable privacy:**
1. Log into domain registrar (GoDaddy, Namecheap, Route53, etc.)
2. Domain settings → Privacy/WHOIS protection → Enable

**Pass criteria:**
- [ ] Domain registrant info hidden (shows privacy proxy, not personal details)
- [ ] Admin and tech contacts also hidden

### 3.7 SSL/TLS Certificate

```bash
# Check certificate validity
openssl s_client -connect your-app.example.com:443 -servername your-app.example.com < /dev/null | grep -A 20 "Certificate"

# Check expiration
echo | openssl s_client -servername your-app.example.com -connect your-app.example.com:443 2>/dev/null | openssl x509 -noout -dates
```

**Pass criteria:**
- [ ] Certificate not expired
- [ ] Certificate matches domain (subject alt name includes your domain)
- [ ] Certificate chain valid (no self-signed for prod)

### 3.8 HSTS (HTTP Strict Transport Security)

```bash
curl -I https://your-app.example.com | grep -i strict-transport-security
# Expected: strict-transport-security: max-age=31536000; includeSubDomains; preload
```

**If missing, add to your web server:**

**Nginx:**
```nginx
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
```

**Express.js (Node.js):**
```javascript
app.use((req, res, next) => {
  res.header("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload");
  next();
});
```

**Python (Flask):**
```python
@app.after_request
def set_hsts(response):
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
    return response
```

**Pass criteria:**
- [ ] HSTS header present with max-age ≥ 31536000 (1 year)
- [ ] includeSubDomains enabled
- [ ] Preload flag set (optional but recommended)

---

## 4. Authentication & Authorization

### 4.1 Session Management

```bash
# Check for secure cookie flags in Network tab of browser DevTools
# Or programmatically:
curl -i https://your-app.example.com | grep -i "set-cookie"
```

**Expected output:**
```
set-cookie: session=abc123; httpOnly; Secure; SameSite=Strict; Max-Age=3600
```

**Manual checks:**
- [ ] `httpOnly` flag set (prevents XSS from stealing session)
- [ ] `Secure` flag set (cookie only sent over HTTPS)
- [ ] `SameSite=Strict` or `SameSite=Lax` (prevents CSRF)
- [ ] Reasonable `Max-Age` (e.g., 1 hour for sensitive, 30 days for remember-me)

### 4.2 Password Policy

```bash
# Check if password policy is enforced
grep -r "minLength\|regex\|strong" src/ --include="*.ts" --include="*.js" --include="*.py" | head -20
```

**Expected:**
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, special chars
- No common weak passwords (123456, password, etc.)

**Hashing verification:**
```javascript
// Node.js - bcrypt
const bcrypt = require("bcrypt");
const hashed = bcrypt.hashSync("password", 10);
console.log("Uses bcrypt:", hashed.startsWith("$2"));

// Python - argon2
from argon2 import PasswordHasher
ph = PasswordHasher()
hashed = ph.hash("password")
print("Uses Argon2:", hashed.startswith("$argon2"))
```

**Pass criteria:**
- [ ] Password policy enforced (min 12 chars, mixed case, numbers, symbols)
- [ ] Uses bcrypt, Argon2, or PBKDF2 (NOT MD5, SHA-1, SHA-256)
- [ ] Salt rounds ≥ 10 for bcrypt

### 4.3 MFA for Admin Accounts

```bash
# Check if admin panel requires MFA
# 1. Log in as admin
# 2. Navigate to settings
# 3. Verify MFA (TOTP, SMS, WebAuthn) is available and required
```

**Implementation example (TOTP):**
```javascript
// Node.js - speakeasy
const speakeasy = require("speakeasy");
const secret = speakeasy.generateSecret({ name: "MyApp (admin@example.com)" });
console.log("Scan this:", secret.qr_code);
```

**Pass criteria:**
- [ ] MFA available for all admin/privileged accounts
- [ ] MFA required (not optional) for admin login
- [ ] Recovery codes provided in case of MFA device loss

### 4.4 API Key Rotation

```bash
# Document API key expiration policy
echo "Current API keys:"
grep -r "X-API-KEY\|Authorization.*Bearer" src/ --include="*.ts" --include="*.js"
```

**Policy (document in README or SECURITY.md):**
- API keys rotate every 90 days
- Old keys retained for 7 days during transition (allow client grace period)
- Stolen keys can be revoked immediately
- Keys stored in env vars, never in code

**Pass criteria:**
- [ ] API key rotation policy documented
- [ ] Key rotation mechanism implemented (can generate new key, invalidate old)
- [ ] No hardcoded keys in code or git history

---

## 5. Monitoring & Observability

### 5.1 Error Tracking (Sentry, Rollbar, etc.)

```bash
# Check if error tracking is initialized
grep -r "Sentry\|Rollbar\|Bugsnag" src/ --include="*.ts" --include="*.js"

# Verify DSN is in env vars, not hardcoded
grep -r "sentry.io\|rollbar.com" src/ --exclude-dir=node_modules
# Should return ZERO (DSN should be env var)
```

**Setup example (Sentry):**
```javascript
import * as Sentry from "@sentry/node";

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,
});
```

**Pass criteria:**
- [ ] Error tracking service configured (Sentry, Rollbar, Bugsnag)
- [ ] DSN in env vars (not hardcoded)
- [ ] Errors automatically captured on production
- [ ] Errors include context (user ID, request ID, stack trace)

### 5.2 Uptime Monitoring

```bash
# Manual test: Does your API respond?
curl -s -o /dev/null -w "%{http_code}" https://your-app.example.com/health
# Expected: 200
```

**Recommended services:**
- Uptimerobot (free)
- StatusPage.io (for public status page)
- Healthchecks.io (simple HTTP checks)

**Setup:**
1. Create health check endpoint (returns 200 if healthy)
2. Configure uptime monitor to ping every 5 minutes
3. Set up alerts (email, Slack) if service is down

**Pass criteria:**
- [ ] Health check endpoint exists and returns 200
- [ ] Uptime monitor configured (Uptimerobot, etc.)
- [ ] Down alerts sent to team (Slack, email, PagerDuty)

### 5.3 Security Alerts

```bash
# Check for failed login spike detection
# Look for code that: logs login attempts, tracks failed counts, alerts on spikes
grep -r "failed.*login\|login.*attempt\|invalid.*password" src/ --include="*.ts" --include="*.js" --include="*.py"
```

**Implementation example:**
```javascript
// Detect brute force: 5+ failed logins in 5 minutes
const failedAttempts = await db.failedLogins.count({
  email,
  createdAt: { $gte: new Date(Date.now() - 5 * 60 * 1000) },
});

if (failedAttempts > 5) {
  // Alert ops: suspicious activity
  await slack.send(`Security Alert: ${failedAttempts} failed logins for ${email}`);
  // Optional: block further attempts
  throw new Error("Too many failed attempts. Try again in 15 minutes.");
}
```

**Pass criteria:**
- [ ] Failed login attempts logged
- [ ] Spike detection alerts configured (e.g., 5+ failures in 5 min)
- [ ] Alerts sent to Slack, email, or monitoring system

### 5.4 Request/Application Logging

```bash
# Check for secrets in logs
grep -r "password\|token\|secret\|apiKey" src/ --include="*.ts" --include="*.js" --include="*.py" | grep -i "console.log\|logger\|print"
# Should show ZERO matches (don't log secrets)
```

**Good practice:**
```javascript
// Log metadata, never secrets
logger.info("User login", {
  userId: user.id,
  email: user.email,
  timestamp: new Date().toISOString(),
  requestId: req.id,
  // DON'T log: password, token, apiKey
});
```

**Pass criteria:**
- [ ] Application logs important events (login, deletion, auth failures)
- [ ] Request ID included in logs (for tracing)
- [ ] No passwords, tokens, or API keys in logs
- [ ] Logs retained for 90+ days (for audit/forensics)

---

## 6. Attack Simulation (Optional but Recommended)

After passing the checklist, simulate common attacks to validate defenses.

### 6.1 Port Scanning

```bash
# Check for unexpected open ports
nmap -sV <your-app-domain-or-ip>
```

**Expected:** Only ports 80, 443, and SSH (22) open. Nothing else.

### 6.2 SSL/TLS Test

```bash
# Comprehensive SSL test
testssl.sh <your-app-domain>

# Or online: https://www.ssllabs.com/ssltest/
```

**Expected:** A+ rating

### 6.3 Security Headers Check

```bash
# Verify all security headers present
curl -I https://your-app.example.com | grep -iE 'x-frame|x-content|strict-transport|x-xss|content-security|referrer-policy'
```

**Expected headers:**
```
x-frame-options: DENY
x-content-type-options: nosniff
strict-transport-security: max-age=31536000; includeSubDomains; preload
x-xss-protection: 1; mode=block
content-security-policy: default-src 'self'; script-src 'self' 'unsafe-inline'
referrer-policy: no-referrer
```

---

## Deployment Approval Checklist

After completing all above items:

- [ ] **OWASP ZAP:** No HIGH findings (or exceptions documented)
- [ ] **Snyk:** No unresolved CVEs ≥ HIGH
- [ ] **security-review skill:** Passed
- [ ] **RLS:** Enabled on all user-facing tables
- [ ] **Database encryption:** SSL/TLS verified
- [ ] **Backups:** Recent backup exists and is restorable
- [ ] **DDoS protection:** Enabled (Cloudflare, AWS Shield, etc.)
- [ ] **Rate limiting:** Configured on APIs
- [ ] **DNSSEC:** Enabled
- [ ] **WHOIS privacy:** Enabled
- [ ] **SSL/TLS:** Valid certificate, no mixed content
- [ ] **HSTS:** Enabled with long max-age
- [ ] **Sessions:** httpOnly, Secure, SameSite flags set
- [ ] **Password policy:** Enforced (12+ chars, complexity)
- [ ] **MFA:** Required for admins
- [ ] **API keys:** Rotatable, env vars only
- [ ] **Error tracking:** Sentry/Rollbar configured
- [ ] **Uptime monitoring:** Uptimerobot or equivalent
- [ ] **Security alerts:** Failed login spike detection
- [ ] **Logging:** Events logged, no secrets exposed
- [ ] **Attack simulation:** Port scan + SSL test passed
- [ ] **Sign-off:** Security lead approved

---

## Next Steps

1. **Run this checklist** before every production deployment
2. **Document exceptions** if any items are N/A or deferred (with timeline)
3. **Automate what you can** (ZAP, Snyk, port scanning, SSL tests) in CI/CD
4. **Review quarterly** — threat landscape changes, new vulns emerge
5. **Post-incident:** Add new checks if you discover a vulnerability in production

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP ZAP](https://www.zaproxy.org/)
- [Snyk](https://snyk.io/)
- [Mozilla HTTPS Observatory](https://observatory.mozilla.org/)
- [SSL Labs](https://www.ssllabs.com/)
- [testssl.sh](https://github.com/drwetter/testssl.sh)
