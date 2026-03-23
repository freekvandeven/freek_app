# Freek App — Copilot Instructions

## Project Overview

This is a Flutter personal life-management app ("Freek App") with Firebase backend.
The codebase is in `personal_app/` with Cloud Functions in `personal_app/functions/`.

## Feedback Workflow

When working on feedback items (bugs or wishes), each item has a **reference ID** (e.g., `BUG-0001`, `WISH-0003`).

### After completing each feedback item:

1. Commit your changes with a conventional commit message.
2. **Submit an AI summary** by running the update script from the repository root:

   ```bash
   ./scripts/update-feedback-summary.sh <REFERENCE_ID> "<Summary of what was done>"
   ```

   Example:
   ```bash
   ./scripts/update-feedback-summary.sh WISH-0005 "Added recipe tag management with autocomplete UI. Tags stored as List<String> on recipe documents. New TagService handles tag CRUD operations."
   ```

   The summary should be concise (1-3 sentences) describing:
   - What was changed or implemented
   - Key technical decisions made
   - Any notable files or components affected

3. If the script fails (e.g., missing API key), note the reference ID and summary in the commit message instead.

## Commit Guidelines

- One feedback item = one commit
- Use conventional commit messages: `fix:`, `feat:`, `chore:`, etc.
- Update `CHANGELOG.md` under the current version section
- Update relevant docs in `docs/` when behavior changes
