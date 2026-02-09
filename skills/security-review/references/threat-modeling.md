# Threat Modeling Reference

> Threat modeling is a structured approach to identifying, communicating, and understanding threats and mitigations within the context of protecting something of value.

---

## When to Threat Model

**Always threat model when:**
- Starting a new project or feature
- Adding authentication/authorization
- Handling sensitive data (PII, financial, health)
- Creating public APIs
- Adding third-party integrations
- Making architectural changes

**Quick threat model for:**
- New endpoints
- New input sources
- New data flows
- Permission changes

---

## The STRIDE Framework

STRIDE helps identify threats by category:

| Category | Description | Security Property |
|----------|-------------|-------------------|
| **S**poofing | Pretending to be someone/something else | Authentication |
| **T**ampering | Modifying data or code | Integrity |
| **R**epudiation | Denying having performed an action | Non-repudiation |
| **I**nformation Disclosure | Exposing information | Confidentiality |
| **D**enial of Service | Making system unavailable | Availability |
| **E**levation of Privilege | Gaining unauthorized access | Authorization |

---

## STRIDE Analysis Process

### Step 1: Decompose the Application

**Create a Data Flow Diagram (DFD):**

```
ELEMENTS TO IDENTIFY:

External Entities (squares)
├── Users
├── External systems
├── Third-party services
└── Administrators

Processes (circles)
├── Web server
├── API handlers
├── Business logic
└── Background workers

Data Stores (parallel lines)
├── Databases
├── File systems
├── Caches
├── Session stores
└── Message queues

Data Flows (arrows)
├── User input
├── API calls
├── Database queries
├── File operations
└── Network requests

Trust Boundaries (dashed lines)
├── Internet ↔ DMZ
├── DMZ ↔ Internal
├── Application ↔ Database
└── Your code ↔ Third-party
```

### Step 2: Apply STRIDE to Each Element

For each element in your DFD, ask:

```
FOR EACH PROCESS:
├── Spoofing: Can this process be impersonated?
├── Tampering: Can its code/config be modified?
├── Repudiation: Are actions logged?
├── Info Disclosure: Does it leak information?
├── DoS: Can it be crashed/overloaded?
└── EoP: Can it gain elevated access?

FOR EACH DATA STORE:
├── Spoofing: N/A (stores don't have identity)
├── Tampering: Can data be modified without auth?
├── Repudiation: Is data modification logged?
├── Info Disclosure: Can unauthorized users read data?
├── DoS: Can storage be exhausted?
└── EoP: N/A (stores don't execute)

FOR EACH DATA FLOW:
├── Spoofing: N/A
├── Tampering: Can data be modified in transit?
├── Repudiation: N/A
├── Info Disclosure: Can data be intercepted?
├── DoS: Can the flow be interrupted?
└── EoP: N/A
```

### Step 3: Document Threats

**Threat documentation template:**

```markdown
## Threat: [Name]

**Category:** [STRIDE category]
**Element:** [Affected component]
**Description:** [What the attacker can do]

**Attack Scenario:**
1. Attacker does X
2. This causes Y
3. Result is Z

**Impact:** [High/Medium/Low]
**Likelihood:** [High/Medium/Low]
**Risk:** [Impact × Likelihood]

**Mitigation:**
- [Control 1]
- [Control 2]

**Residual Risk:** [Risk after mitigation]
```

---

## Example Threat Model: User Login

### Component: Login API Endpoint

**Data Flow:**
```
User → [Internet] → Login API → User DB
                        ↓
                   Session Store
```

**Trust Boundary:** Internet ↔ Login API

### Threats Identified:

#### T1: Credential Stuffing (Spoofing)
- **Description:** Attacker uses leaked credentials from other sites
- **Impact:** High (account takeover)
- **Likelihood:** High (automated attacks common)
- **Mitigation:**
  - Rate limiting per IP and account
  - CAPTCHA after failures
  - Check against known breached passwords
  - MFA for sensitive accounts

#### T2: Brute Force (Spoofing)
- **Description:** Attacker guesses passwords repeatedly
- **Impact:** High (account takeover)
- **Likelihood:** Medium (if rate limiting exists)
- **Mitigation:**
  - Account lockout after N failures
  - Progressive delays
  - Strong password requirements
  - Monitoring for distributed attacks

#### T3: Session Hijacking (Spoofing)
- **Description:** Attacker steals session token
- **Impact:** High (account takeover)
- **Likelihood:** Medium (requires XSS or MITM)
- **Mitigation:**
  - HTTPS only
  - Secure, HttpOnly, SameSite cookies
  - Session binding to IP/User-Agent
  - Short session lifetime

#### T4: Credential Interception (Information Disclosure)
- **Description:** Attacker intercepts credentials in transit
- **Impact:** High (credential theft)
- **Likelihood:** Low (if HTTPS enforced)
- **Mitigation:**
  - HTTPS everywhere
  - HSTS header
  - Certificate pinning for mobile

#### T5: Timing Attack (Information Disclosure)
- **Description:** Attacker determines valid usernames via response time
- **Impact:** Low (information leak)
- **Likelihood:** Medium
- **Mitigation:**
  - Constant-time comparison
  - Same response for invalid user/password
  - Generic error messages

#### T6: Account Enumeration (Information Disclosure)
- **Description:** Attacker determines which accounts exist
- **Impact:** Low (enables targeted attacks)
- **Likelihood:** High (common mistake)
- **Mitigation:**
  - Generic error messages
  - Same response time for all cases
  - CAPTCHA on repeated attempts

---

## Risk Assessment Matrix

| | Low Impact | Medium Impact | High Impact |
|---|---|---|---|
| **High Likelihood** | Medium | High | Critical |
| **Medium Likelihood** | Low | Medium | High |
| **Low Likelihood** | Informational | Low | Medium |

**Risk Treatment Options:**
- **Mitigate:** Implement controls to reduce risk
- **Transfer:** Insurance, third-party handling
- **Accept:** Document and monitor
- **Avoid:** Don't implement the feature

---

## Quick Threat Assessment Questions

**For any new feature, quickly assess:**

1. **Input Sources**
   - What data enters the system?
   - Who can provide this data?
   - Is any of it untrusted?

2. **Authentication**
   - How do we know who the user is?
   - What if authentication is bypassed?
   - Are there any anonymous actions?

3. **Authorization**
   - What can each user type do?
   - What if someone accesses another's data?
   - Are there admin functions?

4. **Data Sensitivity**
   - What data is stored/processed?
   - What if it's leaked?
   - What are compliance requirements?

5. **Dependencies**
   - What external services are used?
   - What if they're compromised?
   - What if they're unavailable?

---

## Threat Modeling Cheat Sheet

```
WHEN REVIEWING CODE, ASK:

Authentication:
□ Can this be accessed without login?
□ Is the session validated?
□ Can credentials be leaked?

Authorization:
□ Is ownership checked?
□ Can one user access another's data?
□ Are admin functions protected?

Input:
□ Is all input validated?
□ Can injection occur?
□ What if input is huge?

Output:
□ Is output encoded?
□ Are errors safe?
□ Is sensitive data filtered?

Data:
□ Is data encrypted at rest?
□ Is data encrypted in transit?
□ Who can access the data store?

Logging:
□ Are security events logged?
□ Are logs protected?
□ Is sensitive data excluded from logs?
```

---

## Resources

- [OWASP Threat Modeling](https://owasp.org/www-community/Threat_Modeling)
- [Microsoft STRIDE](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [OWASP Threat Dragon](https://owasp.org/www-project-threat-dragon/)
- [Threagile (Threat Modeling as Code)](https://threagile.io/)
