## Rule: Authentication/Encryption Separation Mandate

**Rule Statement:** Authentication mechanisms (including passkeys) must never be used directly for data encryption. Cryptographic keys for encryption must be managed through a separate system designed for key lifecycle management and recovery.

---

### Rationale
Using passkeys for data encryption creates a critical risk of **permanent, unrecoverable data loss** due to:
*   **Single Point of Failure:** Loss of the passkey device (phone, hardware key) equals loss of the encryption key.
*   **No Recovery Pathway:** Passkeys lack built-in recovery mechanisms for encrypted data, unlike dedicated authentication systems which may offer account recovery.
*   **Scope Mismatch:** Passkeys are designed for *identity verification* (proving "who you are"), not for *confidentiality* (protecting "what you have").
*   **Phishing Resistance is Irrelevant:** The phishing-resistant property of passkeys does not translate to secure or recoverable encryption key storage.

---

### Implementation Requirements

#### Prohibited & Required Actions

| Prohibited Action | Required Alternative |
| :--- | :--- |
| Deriving an encryption key directly from a passkey or its cryptographic material. | Generate encryption keys using a secure, random key generation function (e.g., `Crypto.getRandomValues()`). |
| Storing encrypted data with no decryption key backup separate from the primary authenticator. | Implement a **separate key management system** with a secure, **user-accessible recovery option**. |
| Relying solely on the user's passkey sync/backup (e.g., iCloud Keychain, Google Password Manager) for encryption key persistence. | Use an explicit key escrow, sealed-box backup to a user's verified secondary device, or a user-accessible backup code/custodial service. |

#### Key Management System Requirements
The separate encryption key management system must provide:
*   **Secure Generation:** Keys must be generated using cryptographically secure random number generators.
*   **Secure Storage:** Encryption keys must be stored encrypted at rest (e.g., wrapped by a key encryption key).
*   **Explicit User Recovery:** A user-initiated recovery process must exist, independent of passkey loss. Examples include:
    *   Backup to a user's secondary authenticated device.
    *   Printed/memorized recovery codes stored securely by the user.
    *   Use of a social recovery or custodial backup service (with clear user consent).
*   **Clear User Communication:** Users must be explicitly warned during setup that losing **both** their primary passkey **and** their encryption key recovery method will result in permanent data loss.

---

### Compliance Verification
To verify compliance, confirm the codebase:
- [ ] **No** direct functional dependency where passkey authentication material is input to a data encryption function.
- [ ] **Existence** of a separate, documented key management module or service for data encryption keys.
- [ ] **Existence** of a user-facing data recovery flow that is functionally independent of the primary passkey authentication event.
- [ ] **Presence** of clear user interface text warning about the responsibility to maintain encryption key recovery methods.

---

### Consequences of Violation
*   **Data Loss:** High probability of irreversible user data loss.
*   **Support Burden:** Inability to assist users who have lost access.
*   **Reputation Damage:** Erosion of trust due to preventable data loss scenarios.
*   **Security Degradation:** May lead to users reusing passwords or avoiding encryption altogether to circumvent the risk.
