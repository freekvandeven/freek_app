# Freek App — Claude Code Instructions

## Project Overview

Flutter personal life-management app ("Freek App") with Firebase backend.
Codebase at repo root; Cloud Functions in `functions/`.

**Stack:** Flutter 3.11+, Dart, Firebase (Auth/Firestore/Storage/Functions), Riverpod 2, GoRouter, Gemini AI, E2E encryption.

## Feedback Workflow

When working on feedback items (bugs or wishes), each has a **reference ID** (e.g., `BUG-0001`, `WISH-0003`).

### After completing each feedback item:

1. Commit with a conventional commit message (one item per commit).
2. Update `CHANGELOG.md` under the current `[Unreleased]` or version section.
3. Run the feedback summary script from the repo root:

   ```bash
   ./scripts/update-feedback-summary.sh <REFERENCE_ID> "<Summary>"
   ```

   The summary should be 1–3 sentences covering what changed, key technical decisions, and notable files.
   If the script fails (missing API key), note the reference ID and summary in the commit message instead.

4. Update relevant docs in `docs/` when behavior changes.

## Commit Guidelines

- **One feedback item = one commit**
- Conventional commit messages: `fix:`, `feat:`, `chore:`, `refactor:`, `test:`, `docs:`
- Always update `CHANGELOG.md`
- Keep commits atomic — do not bundle unrelated changes

## Architecture

```
lib/
├── config/           # App-wide configuration
├── features/         # 21 feature modules (auth, tasks, recipes, finances, inventory, …)
│   └── <feature>/
│       ├── models/
│       ├── pages/
│       ├── providers/   # Riverpod providers (use @riverpod / riverpod_generator)
│       └── services/
├── models/           # Shared data models
├── presentation/     # Shell, theme, shared widgets, top-level pages
├── providers/        # Global providers
├── routing/          # GoRouter config
└── services/         # Shared services
```

**State management:** Riverpod 2 with code-generation (`@riverpod`). Always run `flutter pub run build_runner build --delete-conflicting-outputs` after generating new providers.

**Routing:** GoRouter with shell routes. Add new routes in `lib/routing/`.

**Encryption:** Password vault uses E2E encryption via the `encrypt` package. Do not log or expose plaintext vault data.

## Cloud Functions

After every creation or modification of `functions/`:

1. **Build:** `npm run build` in `functions/` — fix all TypeScript errors before proceeding.
2. **Deploy:** `firebase deploy --only functions --force --non-interactive` from repo root.
3. **Verify:** Check logs after deployment:
   ```bash
   gcloud functions logs read --project=freek-personal-app --region=europe-west4 --gen2 --limit=20
   ```

## Code Style

- Use `riverpod_generator` (`@riverpod`) for new providers — not manual `Provider()` constructors.
- Follow existing file/folder naming: `snake_case` for files, `PascalCase` for classes.
- Run `dart format .` before committing.
- Run `flutter analyze` — zero warnings/errors required.
- No dead code, no unused imports.
- No comments unless the WHY is non-obvious (hidden constraint, workaround, subtle invariant).

## Testing

- Unit tests in `test/` — run with `flutter test test/`.
- Integration tests via `scripts/run-integration-tests.sh` (starts Firebase emulators).
- Pre-commit hook runs `flutter test test/` automatically.

## Key Scripts

| Script | Purpose |
|--------|---------|
| `./scripts/update-feedback-summary.sh <ID> "<text>"` | Post AI summary to feedback item |
| `./scripts/pre-commit.sh` | Lint + test (runs automatically via git hook) |
| `./scripts/run-integration-tests.sh` | Full integration test suite with emulators |
| `./scripts/generate-docs.sh` | Generate Dart + Cloud Functions docs |

## Feature Modules (existing)

`admin`, `auth`, `calendar`, `catalog`, `changelog`, `connections`, `conversations`, `dashboard`, `feedback`, `finances`, `gemini`, `inventory`, `knowledge`, `more`, `notifications`, `passwords`, `people`, `recipes`, `settings`, `shopping`, `tasks`

## Important Notes

- `key.properties` and `*.jks` are gitignored — never commit signing secrets.
- `scripts/.feedback-api-key` is gitignored.
- Firebase project ID: `freek-personal-app`, region: `europe-west4`.
- App version managed in `pubspec.yaml` — bump for releases.
- All prices stored in EUR internally; displayed in user's preferred currency.
