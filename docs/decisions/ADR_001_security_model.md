# ADR-001 — Security Model

## Date

2026-03-08

## Status

Accepted

## Context

Personal App stores sensitive personal data including passwords, financial information, and personal notes. The app is open-source on GitHub, meaning the codebase is publicly visible. We need a security model that:

1. Protects user data at rest and in transit
2. Prevents API key leakage from the repository
3. Provides multi-layer authentication
4. Enables client-side encryption for the most sensitive data

## Options Considered

### Option 1 — Server-side encryption only (Firestore at-rest encryption)

- **Pros**: Simple, no client-side crypto complexity, Firestore encrypts at rest by default
- **Cons**: Data is readable by anyone with Firebase Admin access, no zero-knowledge guarantee

### Option 2 — Client-side encryption for all data

- **Pros**: Full zero-knowledge, maximum privacy
- **Cons**: Extremely complex, kills Firestore query capability, makes CSV export harder

### Option 3 — Hybrid: client-side encryption for sensitive data, Firestore rules for the rest

- **Pros**: Strong security where it matters most, retains Firestore querying for non-sensitive data, practical to implement
- **Cons**: Must clearly define which data is "sensitive"

## Decision

**Option 3 — Hybrid approach.**

### Layers of Security

| Layer | Mechanism | Protects Against |
|-------|-----------|------------------|
| **Transport** | HTTPS (Firebase default) | Network eavesdropping |
| **Authentication** | Firebase Auth | Unauthorized access |
| **Biometric lock** | `local_auth` on app open | Physical device access |
| **Per-screen biometric** | Additional `local_auth` for sensitive screens | Shoulder surfing, temporary access |
| **Firestore rules** | Per-user document isolation | Cross-user data access |
| **Client-side E2E encryption** | AES-256-GCM for Password Vault | Database compromise, admin access |
| **Secret management** | `.env` via GitHub Secrets | API key leakage |

### What Gets Client-Side Encrypted

| Data | Encrypted Fields | Rationale |
|------|-----------------|-----------|
| Password Vault | `encryptedPassword`, `encryptedNotes` | Most sensitive — credentials for external services |

Other data (tasks, recipes, finances, inventory, etc.) is protected by Firestore security rules and Firebase Auth but is not client-side encrypted, preserving query and sort capabilities.

### Encryption Details

- **Algorithm**: AES-256-GCM (authenticated encryption)
- **Key derivation**: PBKDF2 (or Argon2 if library support is good) from master password + per-user salt
- **Salt**: Randomly generated per user, stored in `users/{userId}` document
- **Verification**: A hash of the derived key is stored to verify master password correctness without revealing the key
- **Key lifecycle**: Held in memory only during Password Vault session; cleared on navigation away or app background

### Secret Management

- All Firebase configuration (API keys, project IDs) injected via GitHub Secrets → `.env` files
- `.env` is in both `.gitignore` and `.firebaseignore`
- Template `.env.example` in the repo with placeholder values

## Consequences

### Positive
- Password data is safe even if Firestore is compromised
- No secrets in the git repository
- Multi-layer defense in depth
- Non-encrypted data retains full Firestore query capability

### Negative
- Password Vault data cannot be queried server-side (search must happen client-side after decryption)
- If user forgets master password, encrypted data is permanently lost
- Client-side encryption adds complexity to the Password Vault feature
- Biometric auth is not available on all platforms (web has no `local_auth` support)
