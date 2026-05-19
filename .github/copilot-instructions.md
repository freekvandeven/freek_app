# Freek App — Copilot Instructions

## Project Overview

This is a Flutter personal life-management app ("Freek App") with Firebase backend.
The codebase is at the repository root with Cloud Functions in `functions/`.

## Feedback Workflow

There are three kinds of feedback items, each with their own reference-ID prefix:

| Type | Prefix | When to use |
|------|--------|-------------|
| Bug | `BUG-0001` | Something is broken / behaves incorrectly |
| Wish | `WISH-0003` | A new feature the user wants |
| Improvement | `IMPR-0001` | Refactor / cleanup / non-functional quality improvement (perf, code health, tests, dead-code removal, docs, observability) |

### Filing new items yourself

If, while working, you discover a bug or want to defer an improvement instead of doing it inline, you can create a new feedback item directly with:

```bash
./scripts/create-feedback.sh <bug|wish|improvement> "<TITLE>" "<DESCRIPTION>"
```

Examples:
```bash
./scripts/create-feedback.sh improvement \
  "Drop unused google_generative_ai dependency" \
  "WISH-0067 replaced the SDK with direct HTTP; removing the dep shaves bundle size."

./scripts/create-feedback.sh bug \
  "Knowledge TOC rerenders on every keystroke" \
  "Profiling shows _TocPanel rebuilds for unrelated text edits. Should memoise on heading list."
```

The Cloud Function auto-assigns the next reference ID (e.g. `IMPR-0007`) and prints it. **Don't** file feedback items as a substitute for fixing in-scope work the user has asked you to handle — file them for genuinely out-of-scope discoveries, deferred items, or "we should track this".

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

## Widget State — Prefer flutter_hooks

For new widgets that need ephemeral local state (controllers, focus nodes, animations, simple flags, timers, scroll positions), use `HookWidget` / `HookConsumerWidget` from `flutter_hooks` + `hooks_riverpod` instead of `StatefulWidget` / `ConsumerStatefulWidget`. The common conversions:

| StatefulWidget pattern | Hook replacement |
|---|---|
| `final _c = TextEditingController();` + `dispose()` | `final c = useTextEditingController();` |
| `final _f = FocusNode();` + `dispose()` | `final f = useFocusNode();` |
| `bool _isLoading = false;` + `setState` | `final isLoading = useState(false); isLoading.value = …` |
| `final _formKey = GlobalKey<FormState>();` | `final formKey = useMemoized(() => GlobalKey<FormState>(), const []);` |
| `initState` + `dispose` cleanup pair | `useEffect(() { subscribe(); return unsubscribe; }, deps)` |
| `Timer.periodic` in `initState` + cancel in `dispose` | `useEffect(() { final t = Timer.periodic(...); return t.cancel; }, [interval])` |

**Rules**: hooks must be called in the same order every build — never inside an `if`, loop, or after an early `return`. For widgets that also need Riverpod's `ref`, use `HookConsumerWidget` (not plain `HookWidget`).

Existing `StatefulWidget`s don't need a bulk migration — convert opportunistically when you're already editing the file and the win is clear (multiple controllers, several `setState`-only fields, or a lifecycle pair).

## Commit Guidelines

- One feedback item = one commit
- Use conventional commit messages: `fix:`, `feat:`, `chore:`, etc.
- Update `CHANGELOG.md` under the current version section
- Update relevant docs in `docs/` when behavior changes

## Cloud Functions

After every creation or modification of Cloud Functions (`functions/`):

1. **Build** — run `npm run build` in the `functions/` directory and fix any TypeScript errors.
2. **Deploy** — run `firebase deploy --only functions --force --non-interactive` from the repository root.
3. **Verify** — after deployment, check the Cloud Run logs for runtime errors:
   ```bash
   gcloud functions logs read --project=freek-personal-app --region=europe-west4 --gen2 --limit=20
   ```
   Or test the function directly (e.g. call a callable function, trigger a storage event) and confirm no errors appear.
