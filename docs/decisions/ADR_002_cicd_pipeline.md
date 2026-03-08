# ADR-002 — CI/CD Pipeline

## Date

2026-03-08

## Status

Accepted

## Context

The project needs automated quality checks and deployment. The repository is hosted on GitHub, and the backend is Firebase. We need:
- Quality gates on every PR
- Automated builds
- Automated deployment triggered by git tags

## Options Considered

### Option 1 — GitHub Actions

- **Pros**: Native GitHub integration, free for public repos, extensive marketplace, easy secret management
- **Cons**: YAML-based config can be verbose

### Option 2 — Codemagic

- **Pros**: Purpose-built for Flutter, good mobile build support
- **Cons**: Additional service to manage, cost for private repos

### Option 3 — GitLab CI

- **Pros**: Powerful, good Docker support
- **Cons**: Repo is on GitHub, would need mirroring

## Decision

**Option 1 — GitHub Actions.**

### Workflows

#### 1. PR Quality Check (`ci.yml`)

**Trigger**: Pull request to `master`

**Steps**:
1. Checkout code
2. Setup Flutter
3. Install dependencies (`flutter pub get`)
4. Check formatting (`dart format --set-exit-if-changed .`)
5. Run analyzer (`flutter analyze`)
6. Run tests (`flutter test`)

#### 2. Build & Deploy (`cd.yml`)

**Trigger**: Push of a git tag matching `v*` (e.g., `v1.0.0`)

**Steps**:
1. Checkout code
2. Setup Flutter
3. Inject secrets from GitHub Secrets into `.env`
4. Run quality checks (format, analyze, test)
5. Build web (`flutter build web`)
6. Deploy web to Firebase Hosting
7. Build Android APK/AAB (`flutter build appbundle`)
8. Upload Android build to Firebase App Distribution
9. (Future) Build iOS, macOS, Windows, Linux

#### 3. Firebase Functions Deploy (`functions.yml`)

**Trigger**: Push to `master` when `firebase/functions/` directory has changes

**Steps**:
1. Checkout code
2. Setup Node.js
3. Install dependencies
4. Deploy Cloud Functions to Firebase

### GitHub Secrets Required

| Secret | Purpose |
|--------|---------|
| `FIREBASE_API_KEY` | Firebase Web API key |
| `FIREBASE_PROJECT_ID` | Firebase project identifier |
| `FIREBASE_AUTH_DOMAIN` | Firebase auth domain |
| `FIREBASE_STORAGE_BUCKET` | Firebase storage bucket |
| `FIREBASE_MESSAGING_SENDER_ID` | FCM sender ID |
| `FIREBASE_APP_ID` | Firebase app ID |
| `FIREBASE_MEASUREMENT_ID` | Firebase analytics ID |
| `FIREBASE_SERVICE_ACCOUNT` | Service account JSON for deployment |
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded Android release keystore |
| `ANDROID_KEY_ALIAS` | Android key alias |
| `ANDROID_KEY_PASSWORD` | Android key password |
| `ANDROID_STORE_PASSWORD` | Android store password |

### Conventional Commits

Enforced via:
- PR title validation (GitHub Action or bot)
- Optional: `commitlint` as a pre-commit hook or CI step

### Tag-Based Releases

Release flow:
1. Developer merges PR to `master`
2. Developer creates a git tag: `git tag v1.2.3 && git push --tags`
3. GitHub Actions detects the tag and runs the CD pipeline
4. Web app is deployed to Firebase Hosting
5. Android build is uploaded to Firebase App Distribution

## Consequences

### Positive
- Every PR is automatically checked for code quality
- Deployment is fully automated — just push a tag
- Secrets are managed securely in GitHub
- No manual build or deploy steps needed

### Negative
- iOS builds require a macOS runner (GitHub-hosted or self-hosted) — additional cost
- Android signing requires managing a keystore
- Initial setup of all GitHub Secrets is manual
