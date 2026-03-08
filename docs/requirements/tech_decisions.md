# Technology Decisions

Track the key technology choices for the project.

## Framework Decision

**Status**: Pending — will be decided after requirements review.

| Option | Pros | Cons |
|--------|------|------|
| Traditional Flutter | Full control, larger community, more resources, easier to hire/find help | More boilerplate, manual state/routing/data setup |
| Flutter Flood | Opinionated structure, built-in patterns, less boilerplate | Smaller community, learning curve, dependency on Flood |

**Decision**: _TBD — will be decided after requirements are complete and reviewed._

**Rationale**: _Pending review._

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

**Status**: Pending — depends on framework decision (plain Flutter vs. Flood).

**Options considered**: Provider, Riverpod, Bloc, Flood built-in, GetX

**Decision**: _TBD_

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
| `flutter_native_splash` | Native splash screen | Planned |
| `encrypt` / `pointycastle` | Client-side E2E encryption | Planned |
| `csv` | CSV export functionality | Planned |
| `go_router` or similar | Navigation / routing | Planned |
| `flutter_markdown` | Render markdown in knowledge bank | Planned |
| `intl` | Date formatting, localization | Planned |
| `share_plus` / `clipboard` | Copy feedback to clipboard | Planned |
| `cached_network_image` | Image caching for recipes | Planned |

## Open Questions

- Final framework decision (plain Flutter vs. Flood)
- Which state management approach to use
- Whether to add a linting package like `very_good_analysis`
- Strategy for encrypted fields in Firestore (which library, key derivation)
