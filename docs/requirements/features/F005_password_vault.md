# F005 — Password Vault

## Summary

A secure, encrypted password manager where credentials are encrypted client-side with a user-known master password before being stored in Firestore.

## Priority

High

## User Stories

- US-040 through US-047 (see user_stories.md)

## Description

The Password Vault is the most security-sensitive feature in the app. It allows users to store credentials (username, password, URL, notes) encrypted so that even if the Firestore database is compromised, the passwords remain unreadable.

### Encryption Model
1. **Master Password**: The user sets a master password on first use of the Password Vault. This password is _never_ stored anywhere — not in Firestore, not on device, not in any log.
2. **Key Derivation**: The master password is run through a key derivation function (PBKDF2 or Argon2) with a per-user salt to produce an AES-256 encryption key.
3. **Encryption**: The `password` and `notes` fields of each entry are encrypted with AES-256-GCM before being sent to Firestore.
4. **Decryption**: When retrieving entries, the encrypted fields are decrypted on the client using the derived key.
5. **Session**: The derived key is held in memory for the duration of the vault session. When the user navigates away from the vault or the app goes to background, the key is cleared.

### Entry Management
- **Create**: Title, username, password (encrypted), URL, notes (encrypted), category
- **View**: Decrypted view showing all fields; password hidden by default with a "show" toggle
- **Edit**: Modify any field; re-encrypt on save
- **Delete**: Remove entry from Firestore
- **Copy password**: One-tap to copy decrypted password to clipboard (auto-clear after 30 seconds)

### Biometric Guard
Navigating to the Password Vault requires an additional biometric/device auth prompt (beyond the app-level biometric lock).

### Master Password Verification
- On entering the vault, the user is prompted for their master password
- A verification hash (derived from the master password) is stored to validate that the correct master password was entered, without revealing the password itself
- If the master password is forgotten, encrypted data is unrecoverable (by design)

## Acceptance Criteria

- [ ] User can set a master password on first use of the vault
- [ ] User must enter master password to access the vault each session
- [ ] Biometric re-authentication is required to navigate to the vault
- [ ] Password and notes fields are encrypted client-side before Firestore storage
- [ ] Encryption key is derived from master password and never stored
- [ ] User can create, edit, and delete password entries
- [ ] User can view decrypted entries
- [ ] User can copy a password to clipboard with one tap
- [ ] Clipboard is auto-cleared after 30 seconds
- [ ] User can search and filter entries
- [ ] Master password cannot be recovered (informed during setup)
- [ ] Encryption key is cleared from memory when leaving the vault

## UI / Screens

- S016 — Password Vault (list, requires biometric)
- S017 — Password Entry Detail
- S018 — Password Entry Edit

## Data Requirements

- PasswordEntry entity with `encryptedPassword` and `encryptedNotes` fields (see data_model.md)

## Dependencies

- F001 — Authentication (biometric guard)

## Security Considerations

- **Zero-knowledge**: The server never sees plaintext passwords. Encryption/decryption happens entirely on the client.
- **Key never persisted**: The AES key derived from the master password is only held in memory during the vault session.
- **Salt per user**: Each user has a unique salt stored alongside their profile (the salt alone is not sensitive).
- **Verification without exposure**: A verification hash allows checking if the master password is correct without storing the password or the encryption key.
- **Clipboard security**: Auto-clear clipboard after 30 seconds to prevent password leakage.

## Open Questions

- Exact encryption library: `encrypt`, `pointycastle`, or `cryptography`?
- Should there be a master password change flow (re-encrypt all entries)?
- Should there be a password generator built into the entry editor?
- Backup strategy if user forgets master password (accept data loss, or offer optional recovery key?)
- How to handle the master password prompt on web (no `local_auth`)?
