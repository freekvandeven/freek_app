# Changelog

All notable changes to this project will be documented in this file.

## [0.7.0] - 2026-03-19

### Fixed
- Settings update no longer fails with permission-denied — `updateProfile` now force-refreshes the ID token before Firestore writes and wraps the `publicProfiles` sync in a try-catch so that transient permission errors do not block saving user settings
- Calendar now starts on Monday instead of Sunday
- Profile image upload and Firebase reads no longer fail with permission errors — deployed updated Firestore and Storage security rules to production that support `publicProfiles`, `appConfig`, and profile picture storage paths
- Biometric unlock button now reliably re-prompts on Android after dismissal — calls `stopAuthentication()` before re-authenticating to clear stale biometric session state

### Added
- "This Week" section on the dashboard — shows up to 5 upcoming calendar events (tasks, finance, custom) for the current Mon–Sun week with color-coded icons, day labels, and tap-to-navigate
- Network images are now cached locally using `cached_network_image` — reduces bandwidth, speeds up image loading, and shows images offline across recipes, profiles, conversations, and feedback
- Recipe tag management — tags are auto-lowercased, available tags are persisted in a separate Firestore document (`meta/recipeTags`), and the tag input field shows autocomplete suggestions from previously used tags

## [0.6.0] - 2026-03-18

### Fixed
- Lock screen no longer wipes form state — biometric lock overlay now keeps the app widget tree mounted so in-progress form input is preserved after unlock
- Image upload to Firebase Storage no longer fails with "unauthorized" — force-refresh the ID token before upload to ensure the `inviteVerified` claim is present; show SnackBar on upload errors
- YouTube video embeds no longer show error 150/152 on desktop — desktop platforms (Windows, macOS, Linux) now show a thumbnail card with "Watch on YouTube" button instead of the unreliable WebView embed; web and mobile still use the embedded player with a browser-fallback link
- Currency picker reduced from 24 to 12 common currencies and now shows live EUR conversion rates fetched from the Frankfurter API (ECB data)
- Gemini AI model picker now fetches available models from the API instead of using a hardcoded list — only models supporting content generation are shown
- Dismissing the biometric prompt no longer causes an infinite re-prompt loop — the lock screen stays visible with manual Unlock and Sign Out buttons instead of repeatedly triggering the system dialog

### Added
- Public profiles — profile data (display name, bio, photo) is synced to a `publicProfiles` Firestore collection readable by all verified users; private data (email, phone, settings) stays in the user's own document
- Profile picture upload — tap the avatar on the Profile page to pick and upload a photo from the gallery; photos are stored in Firebase Storage under `users/{uid}/profile/`
- People directory — browse other app users via the new "People" entry in the More menu; tap a user to view their public profile
- Firestore & Storage rules updated for public profile reads and profile photo visibility
- Version check at startup — the app reads `appConfig/version` from Firestore and shows a dialog when an update is available or required; includes "Update" and "Later" actions with a configurable download URL
- Dashboard now shows all features — added Conversations and People tiles to the home screen grid alongside existing entries
- "What's New" link on the dashboard — navigates to the changelog page so users can quickly see recent changes

## [0.5.0] - 2026-03-15

### Fixed
- Password vault navigation — switching apps and returning no longer breaks back navigation; vault pages now preserve the navigation stack and redirect to unlock when vault key is lost

### Added
- Vault re-encryption on password change — after changing your account password, the app offers to re-encrypt your password vault with a new master password matching your new account password
- Attach app logs to feedback entries — capture Flutter errors and app logs in-memory, select and attach them when creating or editing bug reports and wishes; attached logs are included in clipboard export
- Image attachments on feedback — add photos from gallery or camera to bug reports and wishes; images are uploaded to Firebase Storage and displayed as thumbnails on the edit page
- Conversation topics — track discussion topics per person or group with priority (low/medium/high), status (open/resolved), image attachments, filtering by person/status, and sorting by priority or date

## [0.4.0] - 2026-03-14

### Fixed
- Password autofill now works on all platforms — login and signup forms support password manager suggestions via `AutofillGroup` and `autofillHints`, with Digital Asset Links (Android) and Apple App Site Association (iOS/macOS) hosted on Firebase
- Connections quick links now open native apps (Google Calendar, Gmail, Google Drive, Google Keep, GitHub, ChatGPT) when installed, with web fallback
- Feedback entries no longer duplicate when marking as resolved or changing privacy — old document is cleaned up from the opposite collection

### Added
- Gemini API key can now be stored securely on-device via Settings → AI → Gemini API Key, using `flutter_secure_storage`
- AI image scanning for inventory — take a photo of an item and Gemini auto-fills name, description, category, quantity, price, and barcode
- Custom accent color picker in Settings → Appearance with 12 preset colors, stored per-user in Firestore
- Native splash screen with app icon on brand-color background (Android, iOS, Web) via `flutter_native_splash`
- New app icon — gradient brand-color rounded square with stylized "F" monogram, generated for all platforms\n- Video links on recipes — add YouTube, Vimeo, TikTok, and Instagram video URLs; YouTube videos play inline via embedded player, other platforms open in browser
- Gemini model selection — choose between Gemini 2.5 Flash, 2.0 Flash, 1.5 Flash, and 1.5 Pro in Settings → AI → Gemini Model

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
