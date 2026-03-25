#!/usr/bin/env bash
# Generate API documentation for all project components.
#
# Output:
#   docs/generated/dart/    — Flutter/Dart API docs (dart doc)
#   functions/docs/         — Cloud Functions API docs (typedoc)
#
# Usage:
#   ./scripts/generate-docs.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Generating Dart API documentation ==="
cd "$REPO_ROOT/lib"
cd "$REPO_ROOT"
dart doc --output docs/generated/dart 2>&1 | tail -5
echo "Dart docs written to docs/generated/dart/"

echo ""
echo "=== Generating Cloud Functions documentation ==="
cd "$REPO_ROOT/functions"
npm run docs 2>&1 | tail -5
echo "Cloud Functions docs written to functions/docs/"

echo ""
echo "=== Documentation generation complete ==="
echo "Open docs/generated/dart/index.html or functions/docs/index.html in a browser."
