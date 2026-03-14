# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2026-03-14

### Fixed
- Password autofill now works on all platforms — login and signup forms support password manager suggestions via `AutofillGroup` and `autofillHints`, with Digital Asset Links (Android) and Apple App Site Association (iOS/macOS) hosted on Firebase
- Connections quick links now open native apps (Google Calendar, Gmail, Google Drive, Google Keep, GitHub, ChatGPT) when installed, with web fallback
- Feedback entries no longer duplicate when marking as resolved or changing privacy — old document is cleaned up from the opposite collection

### Added
- Gemini API key can now be stored securely on-device via Settings → AI → Gemini API Key, using `flutter_secure_storage`
- AI image scanning for inventory — take a photo of an item and Gemini auto-fills name, description, category, quantity, price, and barcode
- Custom accent color picker in Settings → Appearance with 12 preset colors, stored per-user in Firestore

## [0.3.0] - 2026-03-11

### Added
- Invite-code registration — signup requires a valid single-use invite code
- Cloud Functions backend (`createUserWithInvite`, `blockDirectSignup`, `setInviteVerifiedClaim`)
- Firestore `inviteCodes` collection (admin-only, no client access)
- `inviteVerified` custom claim on users — required by all Firestore security rules
- Blocking function prevents direct client-side user creation via Firebase API key
- Change password page (Settings → Change Password)
- Cross-platform cloud function calls via HTTP (works on Android, iOS, Web, Windows)

### Changed
- Signup page now has an invite code field
- Firestore security rules require `inviteVerified` claim for all data access
- Auth service uses Cloud Function instead of client-side `createUserWithEmailAndPassword`

### Security
- Client-side user creation blocked by `beforeUserCreated` Cloud Function
- Even if a user is created directly with the API key, they cannot access any Firestore data without `inviteVerified` claim
- Invite codes collection completely inaccessible from client
- Password change requires re-authentication with current password

## [0.2.0] - 2026-03-10

### Added
- Wakelock — screen stays on while the app is active (wakelock_plus)
- Feedback items are now shared across users with public/private toggle
- Biometric lock — secure the app with fingerprint or face unlock
- Profile page — edit display name and email
- Recipe image upload via Firebase Storage (gallery, camera, or URL)
- Quick actions menu on the dashboard for fast navigation
- Connections screen — manage linked people and contacts
- Calendar integration — events from tasks, finances, and recipes
- Gemini AI chat assistant
- Changelog screen — browse version history inside the app

### Changed
- Feedback split into dual collections: public at `feedback/` (shared) and private at `users/{userId}/feedback/` (per-user), merged client-side
- Quick actions menu triggers on long press (was double tap) and works on all pages with titles
- Feedback copy-to-clipboard instructions now include CHANGELOG.md update step
- Feedback copy-to-clipboard now instructs per-task commits
- Currency symbols shown throughout the finance section
- Navigation back button behavior fixed across all screens

### Fixed
- Firestore security rules simplified for dual feedback collections
- Lock screen now uses app theme background instead of default grey (moved inside MaterialApp)
- FlutterFragmentActivity for biometric auth on Android
- Firebase web deployment white screen and service worker issues

## [0.1.0] - 2026-02-01

### Added
- Authentication — login, signup, forgot password
- Dashboard with personalized greeting and quick stats
- Task management — CRUD, filtering, sorting, repeatable tasks
- Recipe management — ingredients, instructions, tags, favorites
- Financial tracking — transactions, categories, assets, charts
- Password vault — AES-256 encrypted entries
- Calendar view with table_calendar
- Inventory management — items, categories, locations, search
- Feedback system — wishes, bugs, status tracking, clipboard copy
- Knowledge bank — hierarchical pages, markdown, tags, search
- Settings — theme, currency, data export, logout
- Firebase integration with configurable local/firebase backend
- Firebase Hosting for web deployment
