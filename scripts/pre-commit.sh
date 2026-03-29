#!/usr/bin/env bash
# Pre-commit hook — runs dart format, flutter analyze, and unit tests
# before allowing a commit.
#
# Install: run scripts/setup-hooks.sh from the repository root.
#
# Integration tests are NOT run here (too slow for every commit).
# Run them separately via: bash scripts/run-integration-tests.sh

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "=== Pre-commit: dart format ==="
(cd "$REPO_ROOT" && dart format --set-exit-if-changed lib/ test/ integration_test/)

echo "=== Pre-commit: flutter analyze ==="
(cd "$REPO_ROOT" && flutter analyze)

echo "=== Pre-commit: flutter test (unit tests) ==="
(cd "$REPO_ROOT" && flutter test test/)

echo "=== All checks passed ==="
echo "(Run integration tests separately via: bash scripts/run-integration-tests.sh)"
