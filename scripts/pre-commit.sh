#!/usr/bin/env bash
# Pre-commit hook — runs dart format, flutter analyze, and unit tests
# on the personal_app project before allowing a commit.
#
# Install: run scripts/setup-hooks.sh from the repository root.

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
APP_DIR="$REPO_ROOT/personal_app"

echo "=== Pre-commit: dart format ==="
(cd "$APP_DIR" && dart format --set-exit-if-changed lib/ test/ integration_test/)

echo "=== Pre-commit: flutter analyze ==="
(cd "$APP_DIR" && flutter analyze)

echo "=== Pre-commit: flutter test ==="
(cd "$APP_DIR" && flutter test)

echo "=== All checks passed ==="
