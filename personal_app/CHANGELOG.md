# Changelog

All notable changes to this project will be documented in this file.

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
- Feedback collection moved from per-user to shared Firestore collection
- Quick actions menu triggers on long press (was double tap) and works on all pages with titles
- Feedback copy-to-clipboard instructions now include CHANGELOG.md update step
- Feedback copy-to-clipboard now instructs per-task commits
- Currency symbols shown throughout the finance section
- Navigation back button behavior fixed across all screens

### Fixed
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
