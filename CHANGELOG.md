# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Admin "Force expiry check" action — a Notifications section in the Admin page lets admins immediately run the daily expiry reminder check; a confirmation dialog explains the effect; the result snackbar reports how many users were checked and how many notifications were sent (WISH-0059)
- Heading table of contents on knowledge view pages — on screens ≥ 900px wide, a 220px Contents panel appears on the right listing all H1–H6 headings; H1s are bold, deeper levels are indented 10px per level; clicking any entry scrolls the content to that heading with a smooth animation; hidden on narrow screens (WISH-0056)
- Push new calendar events to Google Calendar — when Google Calendar is connected, newly created events are automatically pushed to the user's primary Google Calendar; a "Sync new events to Google Calendar" toggle in Settings → Calendar (visible only when connected) lets users disable this; enabled by default (WISH-0057)
- Onboarding introduction — five swipeable pages walk through the app's key feature areas on first launch; an Introduction button on the dashboard re-opens them at any time; Skip and Get Started buttons let users move through or exit at their own pace (WISH-0052)
- AI recipe creation — when a Gemini API key is configured, a sparkle button on the new-recipe form lets you describe a recipe in plain language; the AI generates a fully structured recipe (title, description, servings, times, ingredients, instructions, tags, notes) that pre-fills the form for review before saving (WISH-0050)
- Recipe components — link existing recipes as sub-recipes ("components") on any recipe; the detail page shows each component with a tap-to-navigate link; the edit page has a Components section with a searchable recipe picker to add or remove links (WISH-0047)
- WIP (Work In Progress) marking for recipes, knowledge bank items, shopping list items, and feedback entries — toggle per item from the edit/add form; each list page gains a WIP-only filter button (construction icon) to show only items still in progress (WISH-0046)
- Servings adjuster on recipe detail page — tap +/− to change serving count; all ingredient quantities scale proportionally (display only, never saved); reset button restores the original serving count (WISH-0051)
- Responsive navigation rail on large screens — Recipes (600px+), Knowledge & Inventory (900px+) and Gemini AI (1200px+) appear directly in the rail; More only shows items not visible at the current width. Mobile bottom nav keeps 5 items (BUG-0023)
- Markdown toolbar in the knowledge editor with H1/H2/H3, bold, italic, inline code, bullet/numbered list, blockquote, link and horizontal-rule buttons; inserts at line start or wraps the current selection; wrap buttons with no selection place the cursor between the opening and closing markers so typing inserts content immediately (WISH-0048)
- AI Assist button in the knowledge editor app bar — enter a plain-language instruction (e.g. "make it more concise") and Gemini rewrites the markdown in-place without saving; requires a configured Gemini API key (WISH-0049)
- Sub-page creation button on knowledge view pages — an 'Add sub-page' icon in the app bar opens the new-page form with the current page pre-selected as parent, still changeable (WISH-0055)
- Auto-save setting in Settings > Preferences — choose an interval (1, 2, 5, 10, 15, or 30 min) to save knowledge bank pages and recipes in the background while editing; shows a brief snackbar on each save (WISH-0054)

### Fixed
- Knowledge WIP filter now shows WIP child pages even when their parent pages are not WIP — the filter includes every WIP page plus all its ancestors up the tree; ancestor nodes auto-expand so nested WIP pages are immediately visible without manual expansion (BUG-0027)
- Markdown links in the knowledge bank are now tappable — added `onTapLink` callback to `MarkdownBody` using `url_launcher` to open URLs in the external browser on both mobile and web (BUG-0025)
- Web URLs no longer contain a `/#/` hash fragment — `usePathUrlStrategy()` is now called at startup so routes use clean paths like `/tasks` instead of `/#/tasks`; Firebase Hosting already had the required catch-all rewrite (BUG-0024)
- Static text (page titles, labels, body text) is now selectable on web and desktop — wrapped the app in a `SelectionArea` so all `Text` widgets are selectable without replacing them individually; `TextField` inputs retain their own selection behaviour (BUG-0026)
- Removed Kerio Connect integration from the calendar sync menu and the Connections page (WISH-0058)
- Google Calendar integration now guards against unsupported platforms — on Windows and Linux the sync button shows "Not supported on this platform" in the menu and a snackbar explains which platforms are supported (Android, iOS, macOS, web); prevents `MissingPluginException` crashes (BUG-0028)

## [0.7.0] - 2026-03-31

### Added
- Improved Gemini image scan for inventory — AI now receives existing categories and locations for better matching; prompt enhanced to detect quantity, price labels, expiry/best-before dates, and storage location from product images (WISH-0041)
- Push notifications and expiry reminders — FCM integration with token management; configurable reminder days (1, 2, 3, 7, 14, 30 days before expiry) in settings; daily scheduled Cloud Function (`checkExpiryReminders`) sends push notifications for expiring inventory items; automatic cleanup of invalid tokens (WISH-0042)
- Currency conversion — all prices stored in EUR; displayed in user's preferred currency using live ECB exchange rates from Frankfurter API; `CurrencyConverter` with `fromEur`/`toEur` methods; shared `currencyConverterProvider` used by all display and edit pages; edit pages convert input to EUR on save and EUR to user currency on load (WISH-0043)
- Gemini API key vault integration — save and retrieve the Gemini API key from the Password Vault; load from vault button in the API key dialog, automatic offer to save to vault after manual entry; supports multiple vault entries with a picker (WISH-0044)
- Flutter static analysis report on GitHub Pages — `scripts/generate-analysis-report.sh` runs `dart analyze` and generates an HTML report with issue counts, severity breakdown, and codebase metrics; automatically published to GitHub Pages alongside API docs (WISH-0045)
- Android release signing — local keystore with Gradle signing config; `key.properties` and `*.jks` excluded from git; fingerprints documented in README
- Item catalog — create catalog items with title, description, price, link, and multiple images; catalog items serve as the central reference for products across the app
- Inventory-catalog linking — link inventory items to catalog items from the edit page; auto-fills name, description, price, and shares image URLs without storage duplication
- Recipe-catalog linking — pick catalog items when adding recipe ingredients; pre-fills ingredient name and stores the catalog reference
- Shopping list — checklist-style feature (like tasks without due dates) with toggle completion, quantity/unit, catalog item linking, and "clear completed" action; accessible from the More menu
- Static code analysis pipeline — ESLint with typescript-eslint for Cloud Functions, CodeQL security scanning workflow, test coverage reporting via Codecov; all zero-cost via GitHub Actions
- Calendar month/year picker — tap the month header in the calendar to jump to any year and month via a date picker dialog
- Storage usage tracking — user profile now tracks `storageUsedBytes` and `storageLimitBytes`; Cloud Functions (`onFileUploaded`/`onFileDeleted`) automatically update usage on storage events; Settings page shows a storage usage bar with percentage; client-side limit check prevents uploads that would exceed the quota
- Image compression before upload — all image uploads now show a preview dialog with file size and quality presets (Original / Good / Compressed); users can compress images before uploading to save storage space; uses the `image` package for cross-platform JPEG re-encoding
- Test data generation on the developer page — select categories and number of items to create realistic sample data for tasks, recipes, transactions, categories, assets, calendar events, inventory items, feedback, knowledge pages, and conversations
- Integration test runner script (`scripts/run-integration-tests.sh`) that automatically starts/stops Firebase emulators
- Feedback reference IDs — each feedback item gets a unique reference ID (e.g., `BUG-0001`, `WISH-0003`) auto-generated on creation
- AI feedback summaries — cloud function (`updateFeedbackSummary`) accepts AI-generated summaries for feedback items via API key authentication; summaries are visible on the feedback edit page
- Bash script (`scripts/update-feedback-summary.sh`) for submitting AI summaries from the command line (works with or without `jq`)
- Copilot instructions (`.github/copilot-instructions.md`) to guide AI to submit summaries after completing each feedback item
- Feedback list shows reference IDs and robot emoji indicator when an AI summary is available
- Settings profile tile shows the user's profile picture when set, instead of a generic icon
- Calendar events now support start/end times via an all-day toggle; a dedicated event edit page replaces the inline dialog, allowing users to set date, time, end date/time, and description
- Calendar custom events can be edited after creation — tapping a custom event opens the edit page with pre-filled fields
- Tasks now support an optional due time — toggle "Set time" when a due date is set to specify an exact time; time is shown in task list and calendar
- Task image attachments — add photos from gallery or camera to tasks via the edit page; images are uploaded to Firebase Storage with compression preview
- Inventory items now support an expiry date — shown in the list with "EXPIRED" warning when past due; date picker on the edit page
- Inventory items support multiple images — replaced single `imageUrl` with `imageUrls` list; horizontal image gallery with add/remove on the edit page; backward-compatible with existing single-image data
- Admin page for invite code management — admin users can list, create, and delete invite codes via the More page; backed by a new `manageInviteCodes` Cloud Function with admin-only access control
- Admin storage limit management — admins can view and update any user's storage limit from their public profile page; backed by a new `updateStorageLimit` Cloud Function with admin-only access control; Firestore rules updated to allow admin read access to user documents
- Google Calendar integration — connect your Google Calendar from the sync menu on the calendar page; events are fetched via the Google Calendar API and displayed alongside tasks, finance, and custom events; supports silent re-authentication on app restart
- Image preview toggle in settings — new "Image Previews in Lists" setting under Appearance; when enabled (default), inventory list shows item thumbnail images instead of letter avatars, and recipe list shows primary image; toggle persists in user settings
- Grant admin privileges — admins can make other users admin from the public profile page via a new `setAdminClaim` Cloud Function; action is grant-only (cannot revoke) with confirmation dialog; backed by admin-only access control

### Fixed
- Integration test script now uses `flutter drive` with chromedriver for reliable web-based testing — replaces `flutter test` which had Firestore emulator connectivity issues on Windows desktop
- Integration test UI assertions now poll for async results instead of relying on `pumpAndSettle` timeouts — fixes flaky tests when real HTTP calls to emulators take longer than expected
- Pre-commit hook and VS Code test runner no longer hang on integration tests — `dart_test.yaml` restricts default test discovery to `test/` only; pre-commit hook explicitly runs `flutter test test/`; integration tests must be run separately via `scripts/run-integration-tests.sh`
- Recipe edit page now warns the user when there is unsaved text in the tag field before saving, with options to add the tag, discard it, or cancel
- Changelog page now shows the `[Unreleased]` section when it contains entries — displays an "unreleased build" banner and lists all pending changes so testers can see what's new before the next release
- Settings version tile shows an "unreleased changes" badge when the bundled CHANGELOG has unreleased entries
- Changelog "Latest" badge renamed to "Current" and now highlights the entry matching the running app version, rather than always the first entry
- Admin menu item now reliably appears for admin users — fixed token refresh to force-fetch latest custom claims instead of using potentially stale cached token
- Storage usage tracking Cloud Functions (`onFileUploaded`/`onFileDeleted`) now correctly parse file size as a number before passing to `FieldValue.increment()`
- Chinese Yuan (CNY ¥) restored to the currency picker — was inadvertently removed
- Residual images in Firebase Storage — images are now properly deleted from Storage when removed from edit pages, when items are deleted, and when profile photos are updated; image uploads are deferred until the item is saved to prevent orphaned files from cancelled edits
- Info logging throughout the app — added `LogService.instance.info()` calls to auth operations (sign up, sign in, sign out, password reset/change, profile update), all CRUD operations (tasks, inventory, recipes, calendar, conversations, feedback, finances), image upload/delete operations, and app startup; all logs are viewable on the developer page
- Public profile page now reliably shows an "Admin" badge for users who are already admin, instead of the "Grant Admin" button; admin status is fetched via a new `checkAdminStatus` Cloud Function that reads the actual Auth custom claim
- Integration test runner script now checks for Java availability, waits for both Auth and Firestore emulator ports, detects early emulator process exit, and builds Cloud Functions before starting emulators
- Stricter Flutter lint rules — added ~50 lint rules with `strict-casts` and `strict-raw-types` enabled; auto-fixed 75 issues with `dart fix`, manually resolved all `unawaited_futures` and `avoid_dynamic_calls` warnings across lib/, test/, and integration_test/
- OpenAPI 3.0 specification for Cloud Functions (`functions/openapi.yaml`) — documents all 5 callable/HTTP endpoints with request/response schemas, authentication, and error codes
- Auto-generated documentation setup — `dart doc` for Flutter API docs, `typedoc` for Cloud Functions; run `./scripts/generate-docs.sh` to generate both; output is git-ignored
- Calendar event image attachments — custom events now support multiple image attachments via gallery or camera; images are uploaded to Firebase Storage with compression preview; images are automatically deleted from Storage when an event is deleted or images are removed
- GitHub Pages documentation — GitHub Actions workflow auto-builds and deploys Dart API docs and Cloud Functions docs to GitHub Pages on every push to master; no generated files committed to git

## [0.6.0] - 2026-03-19

### Fixed
- Lock screen no longer wipes form state — biometric lock overlay now keeps the app widget tree mounted so in-progress form input is preserved after unlock
- Image upload to Firebase Storage no longer fails with "unauthorized" — force-refresh the ID token before upload to ensure the `inviteVerified` claim is present; show SnackBar on upload errors
- YouTube video embeds no longer show error 150/152 on desktop — desktop platforms (Windows, macOS, Linux) now show a thumbnail card with "Watch on YouTube" button instead of the unreliable WebView embed; web and mobile still use the embedded player with a browser-fallback link
- Currency picker reduced from 24 to 12 common currencies and now shows live EUR conversion rates fetched from the Frankfurter API (ECB data)
- Gemini AI model picker now fetches available models from the API instead of using a hardcoded list — only models supporting content generation are shown
- Dismissing the biometric prompt no longer causes an infinite re-prompt loop — the lock screen stays visible with manual Unlock and Sign Out buttons instead of repeatedly triggering the system dialog
- Settings update no longer fails with permission-denied — `updateProfile` now force-refreshes the ID token before Firestore writes and wraps the `publicProfiles` sync in a try-catch so that transient permission errors do not block saving user settings
- Calendar now starts on Monday instead of Sunday
- Profile image upload and Firebase reads no longer fail with permission errors — deployed updated Firestore and Storage security rules to production that support `publicProfiles`, `appConfig`, and profile picture storage paths
- Biometric unlock button now reliably re-prompts on Android after dismissal — calls `stopAuthentication()` before re-authenticating to clear stale biometric session state

### Added
- Public profiles — profile data (display name, bio, photo) is synced to a `publicProfiles` Firestore collection readable by all verified users; private data (email, phone, settings) stays in the user's own document
- Profile picture upload — tap the avatar on the Profile page to pick and upload a photo from the gallery; photos are stored in Firebase Storage under `users/{uid}/profile/`
- People directory — browse other app users via the new "People" entry in the More menu; tap a user to view their public profile
- Firestore & Storage rules updated for public profile reads and profile photo visibility
- Version check at startup — the app reads `appConfig/version` from Firestore and shows a dialog when an update is available or required; includes "Update" and "Later" actions with a configurable download URL
- Dashboard now shows all features — added Conversations and People tiles to the home screen grid alongside existing entries
- "What's New" link on the dashboard — navigates to the changelog page so users can quickly see recent changes
- "This Week" section on the dashboard — shows up to 5 upcoming calendar events (tasks, finance, custom) for the current Mon–Sun week with color-coded icons, day labels, and tap-to-navigate
- Network images are now cached locally using `cached_network_image` — reduces bandwidth, speeds up image loading, and shows images offline across recipes, profiles, conversations, and feedback
- Recipe tag management — tags are auto-lowercased, available tags are persisted in a separate Firestore document (`meta/recipeTags`), and the tag input field shows autocomplete suggestions from previously used tags
- Manual feedback option — feedback entries can be marked as "Manual" to indicate they are handled outside the app; manual entries are excluded from clipboard/AI export and can be filtered in the list view
- Developer page in Settings — shows app info, Firebase auth details (UID, custom claims), debug actions (force token refresh, clear image cache), and a live scrollable log viewer with level filtering and clipboard export
- Public profile now includes `createdAt` (member since date) — synced to the `publicProfiles` Firestore collection and shown on the public profile page
- Dev build indicator — app bar shows a "DEV" badge when the running version is ahead of the latest stable release in Firebase

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
