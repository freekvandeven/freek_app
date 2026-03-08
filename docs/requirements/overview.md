# App Overview

## Vision

**Personal App** is an all-in-one personal life management application. It serves as a single, secure hub for managing tasks, recipes, finances, passwords, inventory, calendar events, a knowledge bank, and more — all under the user's full control with strong encryption and privacy guarantees.

The app is designed to be self-hostable and forkable: anyone can clone the repository, change a few config values (no Dart code edits), and deploy their own branded instance.

## App Identity

- **App Name**: Personal App
- **Organization**: `nl.freekvandeven`
- **Repository**: Hosted on GitHub at `freekvandeven/freek_app`

## Goals

- [x] Provide a single app for managing everyday personal data (tasks, recipes, finances, passwords, inventory, knowledge, calendar)
- [x] Strong security: biometric authentication, end-to-end encryption for sensitive data, no API keys in the repository
- [x] Multi-platform: Web and Android as primary targets, with iOS, macOS, Windows, and Linux as secondary targets
- [x] Easy to deploy: Firebase backend with automated CI/CD via GitHub Actions
- [x] Forkable: other users can clone and configure without touching Dart code
- [x] Data portability: all backend data exportable to CSV
- [x] Extensible: architecture supports adding new feature modules in the future

## Target Users

The primary user is the repository owner — a single person who wants one app to organize their personal life. However, the project is designed so that anyone can fork it and run their own instance, making it suitable for any technically-inclined individual who values privacy and data ownership.

## Platforms

| Platform | Priority | Status |
|----------|----------|--------|
| Web (browser) | **Primary** | Planned |
| Android | **Primary** | Planned |
| iOS | Secondary | Planned |
| macOS | Secondary | Planned |
| Windows | Secondary | Planned |
| Linux | Secondary | Planned |

## Key Constraints

- **No secrets in the repository**: All API keys, Firebase config, and sensitive config are injected via GitHub Secrets into `.env` files at build time. `.env` files are gitignored and also ignored by Firebase Hosting.
- **Conventional commits**: Every commit must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.
- **Code quality gates**: Every PR and commit must pass `dart format`, `flutter analyze`, and all tests.
- **Firebase-only backend**: Firebase is used for authentication, Firestore, Cloud Functions, Hosting, and App Distribution.
- **Configurable branding**: App name, organization, colors, and Firebase project are all driven by configuration files — no Dart code changes needed to rebrand.

## Open Questions

- Final decision on using plain Flutter vs. Flutter Flood (to be decided after requirements review)
- Exact minimum SDK versions for Android and iOS
- Whether to support offline-first or online-only initially
- Notification strategy for inventory expiry reminders (push notifications, in-app, or both)
