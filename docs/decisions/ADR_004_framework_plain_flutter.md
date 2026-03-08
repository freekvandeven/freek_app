# ADR-004 — Framework: Plain Flutter (No Flood)

## Date

2026-03-08

## Status

Accepted

## Context

The project currently has a skeleton Flutter Flood app (`personal_flood_app`). Before building features, we needed to decide whether to continue with Flutter Flood or switch to plain Flutter.

The app requires:
- 10 features, 32 screens, 12 data entities
- Deep Firebase integration (Auth, Firestore, Cloud Functions, Hosting, App Distribution)
- Client-side AES-256 encryption for the Password Vault
- Biometric authentication with per-screen route guards
- Rich UI: calendar views, pie charts, Markdown rendering, dynamic forms
- 6-platform support (Web, Android, iOS, macOS, Windows, Linux)
- Forkability — other users should be able to understand and customize the codebase

## Options Considered

### Option 1 — Flutter Flood

- **Pros**: Opinionated structure, built-in routing/auth/repository abstractions, less boilerplate for simple CRUD
- **Cons**:
  - Small community, limited documentation
  - `StyledPage`/`StyledText` widgets conflict with using Flutter's standard `Theme`/`ColorScheme` system
  - Auth/repository abstractions add indirection over Firebase SDKs without clear benefit
  - No built-in support for client-side encryption, biometric guards, calendar, charts, or Markdown
  - Harder for fork users to understand and modify
  - Dependency on a single maintainer's Git repo (`JLogical-Apps/flood`)

### Option 2 — Plain Flutter

- **Pros**:
  - Massive community, extensive documentation
  - Direct Firebase SDK access — no abstraction overhead
  - Standard `Theme`/`ColorScheme` used everywhere (matches requirements)
  - `go_router` provides typed routes with redirect/guard support for biometric auth
  - Riverpod for state management — compile-safe, testable, widely adopted
  - All planned packages (`local_auth`, `fl_chart`, `table_calendar`, `flutter_markdown`, etc.) are designed for plain Flutter
  - More approachable for forks
- **Cons**:
  - More initial boilerplate for project structure, DI, routing setup

## Decision

**Plain Flutter** with `go_router` for routing and `Riverpod` for state management.

### Architecture Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (plain) |
| State management | Riverpod |
| Routing | go_router (typed routes, redirect guards) |
| Backend | Firebase (Auth, Firestore, Cloud Functions, Hosting) |
| Theming | Flutter `ThemeData` + `ColorScheme` |
| Config | `.env` via `flutter_dotenv` |

### Migration Plan

The existing `personal_flood_app` Flood code will be replaced with a fresh plain Flutter project. Since the existing code is a skeleton (home page + style only), there is no significant code to migrate.

## Consequences

### Positive
- Direct Firebase SDK usage — simpler, better documented, fewer bugs
- Standard Flutter patterns — easier for AI tools and community to assist
- Full control over routing, including biometric guards and deep linking
- Theme system aligns with requirements (ColorScheme, light/dark mode)
- All planned packages work out of the box
- Forkable and understandable codebase

### Negative
- Slightly more boilerplate for initial project setup (routing, DI, service classes)
- No opinionated structure — requires disciplined code organization (mitigated by clear feature-based folder structure)
