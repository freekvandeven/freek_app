# Non-Functional Requirements

Requirements that define *how* the app should behave, not *what* it does.

## Platforms & Compatibility

| Platform | Priority | Minimum Version |
|----------|----------|-----------------|
| Android | **Primary** | API 23 (Android 6.0) — required for biometrics |
| Web (Chrome, Firefox, Safari, Edge) | **Primary** | Latest 2 major versions |
| iOS | Secondary | iOS 14+ |
| macOS | Secondary | macOS 11+ |
| Windows | Secondary | Windows 10+ |
| Linux | Secondary | Ubuntu 20.04+ / equivalent |

## Performance

- App launch to interactive: < 3 seconds on mid-range devices
- Screen transitions: 60fps target, no jank
- Firestore queries: < 1 second for typical data sets (< 10,000 documents per collection per user)
- Splash screen displayed during initialization

## Splash Screen

- **Native splash screen**: Shown by the OS while the Flutter engine loads (using `flutter_native_splash`)
- **Flutter splash screen**: Shown while Firebase initializes and authentication state is resolved
- Both splash screens should use the app's branding (logo, colors)

## Offline Support

- **Initial approach**: Online-first with Firestore's built-in offline persistence
- Firestore SDK caches data locally automatically
- App should gracefully handle no-network situations with informative messages
- Full offline-first mode is a future consideration

## Authentication & Security

### Authentication
- [x] User authentication required — mandatory on first launch
- [x] Firebase Authentication for user identity (email/password at minimum)
- [x] Device-level biometric / PIN authentication on every app open (using `local_auth`)
- [x] Per-page biometric re-authentication for sensitive screens (e.g., Password Vault)
- [x] User can log out

### Data Encryption
- [x] Sensitive collections (Password Vault) are encrypted client-side before storing in Firestore
- [x] Encryption key derived from a user-known secret (e.g., master password) — never stored on the server
- [x] Standard Firestore security rules to ensure users can only access their own data
- [x] HTTPS enforced for all network communication (Firebase default)

### Secret Management
- [x] No API keys, Firebase config, or secrets committed to the repository
- [x] All secrets injected via GitHub Secrets → `.env` files at build time
- [x] `.env` files are in `.gitignore` and `.firebaseignore`

See also: [Security Documentation](../decisions/ADR_001_security_model.md)

## Theming & Design

- [x] Well-defined `ColorScheme` in Flutter `ThemeData`
- [x] All widgets must use `Theme.of(context).colorScheme` — no hardcoded colors
- [x] Support for light and dark mode
- [x] Color scheme and branding configurable via config file (for forkability)

## Navigation

- [x] Clear, consistent navigation structure (bottom navigation bar or drawer)
- [x] Deep linking support for web
- [x] Named routes for all screens
- [x] Smooth transitions between screens

## Accessibility

- [ ] Screen reader support (Semantics widgets)
- [ ] Dynamic text sizing (respect system font size)
- [ ] Sufficient contrast ratios (WCAG AA)
- Priority: Medium — address after core features are built

## Internationalization (i18n)

- [ ] Multi-language support
- Initial language: English only
- Architecture should support adding translations later (use `intl` or `arb` files)
- Priority: Low — future enhancement

## Data & Storage

- **Primary storage**: Cloud Firestore (per-user collections)
- **Local cache**: Firestore SDK offline persistence
- **Data export**: All data exportable to `.csv` via Cloud Functions or in-app export
- **Data portability**: CSV export enables migration to other systems in the future
- **Backup**: Firestore automatic backups + user-initiated CSV exports

## Testing

- **Unit tests**: All business logic and data models
- **Widget tests**: Key screens and components
- **Integration tests**: Critical flows (login, CRUD operations)
- **CI enforcement**: All tests must pass on every PR
- **Code quality**: `dart format` and `flutter analyze` must pass with zero issues

## Forkability

- [x] App name configurable (no hardcoded "Personal App" in Dart code)
- [x] Organization / bundle ID configurable
- [x] Firebase project configurable via `.env`
- [x] Color scheme configurable via config
- [x] A `SETUP.md` guide for forks explaining what to change

## Open Questions

- Exact biometric re-authentication trigger strategy (time-based? every navigation?)
- Push notification support for inventory expiry reminders
- Maximum data limits per user (Firestore cost considerations)
- Whether to add rate limiting on Cloud Functions
