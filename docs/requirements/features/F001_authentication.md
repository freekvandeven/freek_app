# F001 — Authentication & Security

## Summary

User authentication via Firebase Auth with mandatory biometric/device lock on every app open, and optional per-screen biometric re-authentication for sensitive areas.

## Priority

High

## User Stories

- US-001: Sign up with email/password
- US-002: Log in with email/password
- US-003: Biometric/device auth on every app open
- US-004: Logout
- US-005: Per-screen biometric re-authentication
- US-006: Password reset

## Description

### Firebase Authentication
The app uses Firebase Authentication for identity management. On first launch, the user must create an account or sign in. Supported auth methods:
- **Email + password** (required, initial implementation)
- Social login (Google, Apple) — future enhancement

### Biometric Lock
Every time the app is opened (cold start or return from background after a timeout), the user must authenticate via the device's authentication method:
- Biometric (fingerprint, face recognition) if available
- Device PIN/pattern as fallback

This is implemented using the `local_auth` package and is independent of Firebase Auth — it's a local security gate.

### Per-Screen Biometric Guard
Certain sensitive screens (e.g., Password Vault) require an additional biometric prompt before navigation is allowed. This is implemented as a route guard / middleware.

### Session Management
- Firebase Auth session persists across app restarts (user stays "logged in")
- Biometric lock is enforced on every app open regardless
- Logout clears the Firebase Auth session

## Acceptance Criteria

- [ ] User can create an account with email and password
- [ ] User can log in with email and password
- [ ] User sees biometric/device auth prompt on every app open
- [ ] App is inaccessible without passing biometric/device auth
- [ ] User can log out and is returned to the login screen
- [ ] Password Vault requires additional biometric prompt to access
- [ ] User can reset password via email
- [ ] Auth state persists across app restarts
- [ ] Firestore security rules enforce that users can only access their own data

## UI / Screens

- S001 — Splash Screen
- S002 — Login
- S003 — Biometric Lock

## Data Requirements

- User Profile entity (see data_model.md)
- Firebase Auth user record

## Dependencies

- None (this is a foundational feature)

## Open Questions

- Should social login (Google, Apple) be included in v1 or deferred?
- How long should the app be in background before requiring biometric re-auth? (immediate, 1 min, 5 min?)
- Should biometric be required on web? (web doesn't support local_auth — need alternative)
