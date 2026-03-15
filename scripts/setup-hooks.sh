#!/usr/bin/env bash
# Installs the pre-commit hook into the local .git/hooks directory.
# Run this once after cloning the repository:
#
#   bash scripts/setup-hooks.sh

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_SRC="$REPO_ROOT/scripts/pre-commit.sh"
HOOK_DST="$REPO_ROOT/.git/hooks/pre-commit"

if [ ! -f "$HOOK_SRC" ]; then
  echo "Error: $HOOK_SRC not found."
  exit 1
fi

cp "$HOOK_SRC" "$HOOK_DST"
chmod +x "$HOOK_DST"

echo "Pre-commit hook installed at $HOOK_DST"
