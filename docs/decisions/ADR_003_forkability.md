# ADR-003 — Forkability & Configuration

## Date

2026-03-08

## Status

Accepted

## Context

The app should be easily forkable — another person should be able to clone the repository, change some configuration files (without editing Dart code), and deploy their own branded instance with their own Firebase project.

## Options Considered

### Option 1 — Hardcoded values with search-and-replace guide

- **Pros**: Simple to implement
- **Cons**: Fragile, easy to miss a spot, requires Dart edits

### Option 2 — Configuration-driven with `.env` and config files

- **Pros**: Clean separation, no code edits needed, same mechanism used for secrets
- **Cons**: Slightly more initial setup

## Decision

**Option 2 — Configuration-driven.**

### Configuration Sources

| Config | Source | Contains |
|--------|--------|----------|
| Firebase credentials | `.env` (injected from GitHub Secrets) | API keys, project ID, etc. |
| App branding | `config.yaml` or `.env` | App name, organization, theme colors |
| Platform config | `AndroidManifest.xml`, `Info.plist`, etc. | Bundle ID, app name |

### What a Fork User Needs to Do

1. **Create a Firebase project** and enable Auth, Firestore, Hosting, App Distribution
2. **Set up GitHub Secrets** with their Firebase credentials
3. **Edit `.env.example`** values (or configure GitHub Secrets) for:
   - Firebase credentials
   - App display name
   - Organization identifier
4. **Edit platform files** (one-time):
   - Android: `android/app/build.gradle` — `applicationId`
   - iOS: `ios/Runner.xcodeproj` — bundle identifier
   - Web: `web/index.html` — title
5. **Deploy**: Push a tag to trigger CI/CD

### Config File Structure

```
.env.example          # Template with placeholder values (committed)
.env                  # Actual values (not committed, generated in CI)

assets/
  config.yaml         # App branding (name, default theme, etc.)
```

## Consequences

### Positive
- Clean fork experience — no Dart code edits
- Same config mechanism for local dev and CI
- Branding is centralized

### Negative
- Platform files (bundle ID) still need manual one-time edits
- Need to document the setup process clearly in `SETUP.md`
