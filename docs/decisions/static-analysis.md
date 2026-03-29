# Static Code Analysis

This project uses multiple layers of static analysis with zero hosting costs — all tools run via GitHub Actions or locally.

## Dart / Flutter Analysis

| Tool | Purpose | Where |
|------|---------|-------|
| `flutter analyze` | Dart static analysis with strict casts & raw types | CI + pre-commit hook |
| `flutter_lints` | Community-curated lint rules | `analysis_options.yaml` |
| `riverpod_lint` | Riverpod-specific best practices | via `custom_lint` |
| `dart format` | Code formatting enforcement | CI + pre-commit hook |

**Configuration**: see [`analysis_options.yaml`](../../analysis_options.yaml) — 80+ lint rules across style, safety, readability, type safety, and code organization categories.

### Running locally

```bash
flutter analyze
dart format --set-exit-if-changed lib/ test/ integration_test/
```

## Cloud Functions (TypeScript) Analysis

| Tool | Purpose | Where |
|------|---------|-------|
| TypeScript compiler | Strict type checking (`strict: true`) | CI (`npm run build`) |
| ESLint + typescript-eslint | Linting with type-aware rules | CI (`npm run lint`) |

**Configuration**: see [`functions/eslint.config.mjs`](../../functions/eslint.config.mjs)

Key rules:
- `no-floating-promises` — catches missing `await`
- `no-misused-promises` — prevents promise misuse in conditionals
- `no-unused-vars` — dead code detection (ignores `_` prefixed args)
- Type-safety warnings for `any` usage

### Running locally

```bash
cd functions
npm run lint        # check
npm run lint:fix    # auto-fix
```

## Security Scanning (CodeQL)

GitHub CodeQL runs automatically on:
- Every push/PR that changes `functions/src/`
- Weekly schedule (Monday 06:00 UTC)

Results appear in the repository's **Security > Code scanning** tab.

## Test Coverage

Coverage is generated during CI and uploaded to [Codecov](https://codecov.io).

### Running locally

```bash
flutter test --coverage
# Coverage report at coverage/lcov.info
```

To generate an HTML report locally:

```bash
# Install lcov (e.g., brew install lcov on macOS)
genhtml coverage/lcov.info -o coverage/html
```

## CI Pipeline Summary

| Job | Trigger | What it does |
|-----|---------|-------------|
| **Quality** | push/PR to master | Format check, `flutter analyze`, unit tests with coverage |
| **Cloud Functions Lint** | push/PR to master | Build + ESLint on TypeScript functions |
| **Integration** | push/PR to master | Firebase emulator integration tests |
| **CodeQL** | push/PR (functions/) + weekly | Security vulnerability scanning |
| **Docs** | push to master | API docs generation + GitHub Pages deploy |
