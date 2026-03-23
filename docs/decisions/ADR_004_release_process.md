# ADR-004 — Release Process

## Date

2026-03-19

## Status

Accepted

## Context

The project needs a documented, repeatable release workflow. Releases must be explicitly triggered by the developer (never automated) and should produce tagged versions, update Firebase version tracking, and in the future trigger CD builds.

## Decision

### Release Workflow

A release is performed **only when the developer explicitly indicates it is ready**. The steps are:

1. **Update version** — Bump `version` in `personal_app/pubspec.yaml` (e.g., `0.6.0+6`)
2. **Update CHANGELOG** — Add a dated section in `personal_app/CHANGELOG.md` for the new version
3. **Commit** — Commit all changes: `git add -A && git commit -m "release: vX.Y.Z"`
4. **Tag** — Create an annotated git tag: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
5. **Push** — Push commit and tag: `git push && git push origin vX.Y.Z`
6. **Update Firebase** — Run the update script from `personal_app/functions/`:
   ```bash
   npm run update-version -- 0.6.0
   # With optional flags:
   npm run update-version -- 0.6.0 --min-required 0.5.0 --update-url https://example.com/app.apk
   ```
   This updates the Firestore `appConfig/version` document with:
   - `latest`: the new version string (e.g., `"0.6.0"`)
   - `minRequired`: the oldest version still supported
   - `updateUrl`: download URL for the latest build

   **Prerequisite**: Authenticate via `gcloud auth application-default login`

### Version Scheme

- Format: `MAJOR.MINOR.PATCH+BUILD` (e.g., `0.6.0+6`)
- The `+BUILD` number is the cumulative build count and increments with each release
- Pre-release / dev builds use the same version in pubspec but are **not tagged** — the app detects it is a dev build when its version is ahead of the `latest` field in Firebase `appConfig/version`

### Dev Build Detection

The app compares its own version (from `package_info_plus`) against `appConfig/version.latest` in Firestore:
- **Current > latest** → "DEV" badge shown in the dashboard app bar
- **Current < latest** → "Update Available" dialog
- **Current < minRequired** → "Update Required" dialog (non-dismissible)

### Future: CD Pipeline on Tag Push

When a `v*` tag is pushed to GitHub, a CD workflow (`cd.yml`) should:
1. Run quality checks (format, analyze, test)
2. Build for all target platforms (Web, Android, iOS, Windows, macOS, Linux)
3. Deploy the web build to Firebase Hosting
4. Upload mobile builds to Firebase App Distribution
5. Create a GitHub Release with build artifacts

See [ADR-002](ADR_002_cicd_pipeline.md) for the planned CI/CD architecture.

## Consequences

### Positive
- Clear, repeatable release process with no ambiguity
- Dev builds are visually distinguishable from stable releases
- Version checking ensures users are notified of updates
- Tag-based releases integrate cleanly with future CD automation

### Negative
- Firebase `appConfig/version` requires running the update script manually (see step 6)
- CD pipeline for all platforms is not yet implemented
