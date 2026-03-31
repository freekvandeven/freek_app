# Technology Decisions

Track the key technology choices for the project.

## Framework Decision

**Status**: Decided

| Option | Pros | Cons |
|--------|------|------|
| Plain Flutter | Full control, larger community, more resources, direct Firebase SDK access, standard Theme/ColorScheme | More boilerplate, manual state/routing/data setup |
| Flutter Flood | Opinionated structure, built-in patterns, less boilerplate | Small community, limited docs, extra abstraction over Firebase, styled widgets conflict with Theme system, harder for forks to understand |

**Decision**: **Plain Flutter** (no Flood)

**Rationale**: See [ADR-004](../decisions/ADR_004_framework_plain_flutter.md). The project requires deep Firebase integration, client-side encryption, biometric route guards, rich UI packages (calendar, charts, Markdown), and 6-platform support. Plain Flutter provides direct access to the Firebase SDKs, huge community support, well-documented packages, and a more approachable codebase for forks. Flood's abstractions would add complexity without proportional benefit for this feature set.

---

## Backend

**Status**: Decided

**Options considered**: Firebase, Supabase, custom API, local-only

**Decision**: **Firebase**

**Rationale**: Firebase provides a comprehensive, easy-to-host backend with minimal operational overhead. The following Firebase services will be used:

| Firebase Service | Purpose |
|-----------------|---------|
| **Firebase Authentication** | User login (email/password, social, biometric triggers) |
| **Cloud Firestore** | Primary database for all user data |
| **Cloud Functions** | Server-side logic (data export, scheduled tasks, security rules) |
| **Firebase Hosting** | Hosting the web version of the app |
| **Firebase App Distribution** | Distributing test builds to testers |
| **Firebase Cloud Messaging** (optional) | Push notifications (inventory expiry reminders, etc.) |

All Firebase infrastructure (Firestore rules, Cloud Functions code, hosting config) will be included in the project repository.

---

## CI/CD

**Status**: Decided

**Decision**: **GitHub Actions**

### Pipeline Overview

| Trigger | Action |
|---------|--------|
| PR created/updated | Run `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` |
| Push to `master` | Same checks + build artifacts |
| Git tag (e.g. `v1.0.0`) | Build release + deploy to Firebase Hosting + Firebase App Distribution |

### Conventional Commits

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):
- `feat:` — new feature
- `fix:` — bug fix
- `docs:` — documentation only
- `style:` — formatting, no code change
- `refactor:` — refactoring
- `test:` — adding/updating tests
- `chore:` — maintenance, dependencies, CI config
- `ci:` — CI/CD changes

---

## Configuration & Secrets

**Status**: Decided

**Decision**: `.env` files injected at build time via GitHub Secrets.

### How it works:
1. The repository contains **no API keys or Firebase config** — only template/example files.
2. GitHub Secrets store all sensitive values (Firebase API keys, project IDs, etc.).
3. GitHub Actions workflows inject secrets into `.env` files before building.
4. `.env` is listed in `.gitignore` **and** in `.firebaseignore` so it is never committed or deployed to Firebase Hosting.
5. The app reads configuration from `.env` at runtime using a dotenv package.

### Forkability:
Anyone cloning the repo can:
1. Set up their own Firebase project.
2. Configure their own GitHub Secrets.
3. Optionally change branding values in a config file (app name, colors, organization).
4. Build and deploy without modifying any Dart code.

---

## State Management

**Status**: Decided

**Options considered**: Provider, Riverpod, Bloc, GetX

**Decision**: **Riverpod**

**Rationale**: Riverpod provides compile-safe dependency injection, fine-grained reactivity, excellent testability, and no `BuildContext` dependency for accessing state. It pairs well with `go_router` and Firebase, has an active community, and is the modern successor to Provider.

---

## Password Autofill & Associated Domains

**Status**: Decided

**Decision**: Use platform-native autofill with Firebase Hosting as the association domain.

**How it works**:
- Flutter's `AutofillGroup` and `autofillHints` enable password manager suggestions on all platforms.
- **Android**: Digital Asset Links (`/.well-known/assetlinks.json`) hosted on `freek-personal-app.web.app` associates the Android app (package `nl.freekvandeven.personal_app`) with the domain. The `AndroidManifest.xml` has an `autoVerify` intent-filter for the same domain.
- **iOS/macOS**: Apple App Site Association (`/.well-known/apple-app-site-association`) hosted on the same domain associates the iOS app (bundle `nl.freekvandeven.personalApp`). The `Runner.entitlements` file declares `webcredentials` and `applinks` for the domain.
- **Web**: Autofill works natively via browser password managers.
- **Windows/Linux/Desktop**: Autofill hints are provided; behavior depends on the installed password manager.

---

## Packages (Planned)

Track key third-party packages planned for the project.

| Package | Purpose | Status |
|---------|---------|--------|
| `firebase_core` | Firebase initialization | Planned |
| `firebase_auth` | Authentication | Planned |
| `cloud_firestore` | Firestore database | Planned |
| `cloud_functions` | Cloud Functions client | Planned |
| `flutter_dotenv` | Load `.env` configuration | Planned |
| `local_auth` | Biometric / device authentication | Planned |
| `flutter_native_splash` | Native splash screen | In use |
| `encrypt` / `pointycastle` | Client-side E2E encryption | Planned |
| `csv` | CSV export functionality | Planned |
| `go_router` | Navigation / routing with typed routes and guards | Planned |
| `flutter_riverpod` | State management and dependency injection | Planned |
| `flutter_markdown` | Render markdown in knowledge bank | Planned |
| `intl` | Date formatting, localization | Planned |
| `share_plus` / `clipboard` | Copy feedback to clipboard | Planned |
| `cached_network_image` | Image caching for recipes | Planned |
| `url_launcher` | Open external links (Google Calendar, Kerio, etc.) | Added |
| `google_generative_ai` | Google Gemini AI chat integration | Added |
| `flutter_secure_storage` | Secure on-device storage for API keys and secrets | Added |\n| `youtube_player_iframe` | Cross-platform embedded YouTube player for recipe videos | Added |

## Open Questions

- Strategy for encrypted fields in Firestore (which library, key derivation)
- Chart library choice (`fl_chart` vs. `syncfusion_flutter_charts`)
- Calendar package choice (`table_calendar` vs. custom)

---

## Static Analysis & Documentation Pipeline

**Status**: Decided

**Decision**: Automated static analysis report published to GitHub Pages alongside API docs.

**How it works**:
1. The `docs.yml` GitHub Actions workflow runs `dart analyze --format=machine` on every push to master.
2. `scripts/generate-analysis-report.sh` converts analysis output into an HTML report with severity counts, codebase metrics (file/line counts), and a detailed issues table.
3. The report is deployed to GitHub Pages at `/analysis/` alongside Dart API docs (`/dart/`) and Cloud Functions docs (`/functions/`).
4. The pipeline includes: `flutter_lints` ruleset + custom rules, `strict-casts`, `strict-raw-types`, and ~50 additional lint rules.

**Reports available at**: `https://<owner>.github.io/<repo>/analysis/`
