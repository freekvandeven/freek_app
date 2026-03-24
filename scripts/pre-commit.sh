#!/usr/bin/env bash
# Pre-commit hook — runs dart format, flutter analyze, unit tests,
# and integration tests (with Firebase emulators) before allowing a commit.
#
# Install: run scripts/setup-hooks.sh from the repository root.
#
# Prerequisites for integration tests:
#   - Firebase CLI installed (npm install -g firebase-tools)
#   - Java runtime (required by Firestore emulator)

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"

echo "=== Pre-commit: dart format ==="
(cd "$REPO_ROOT" && dart format --set-exit-if-changed lib/ test/ integration_test/)

echo "=== Pre-commit: flutter analyze ==="
(cd "$REPO_ROOT" && flutter analyze)

echo "=== Pre-commit: flutter test (unit tests) ==="
(cd "$REPO_ROOT" && flutter test test/)

# --- Integration tests (with Firebase emulators) ---

# Check prerequisites for emulator-based integration tests
if ! command -v java &>/dev/null; then
  echo ""
  echo "=== Skipping integration tests: Java not found ==="
  echo "Install a Java runtime (JDK 11+) and add it to PATH to enable integration tests."
  echo "=== All other checks passed ==="
  exit 0
fi

if ! command -v firebase &>/dev/null; then
  echo ""
  echo "=== Skipping integration tests: Firebase CLI not found ==="
  echo "Install via: npm install -g firebase-tools"
  echo "=== All other checks passed ==="
  exit 0
fi

AUTH_PORT=9099
EMULATOR_PID=""

cleanup() {
  if [ -n "$EMULATOR_PID" ]; then
    echo ""
    echo "=== Stopping Firebase emulators ==="
    kill "$EMULATOR_PID" 2>/dev/null || true
    wait "$EMULATOR_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if curl -sf "http://localhost:$AUTH_PORT/" >/dev/null 2>&1; then
  echo "=== Firebase emulators already running ==="
else
  echo "=== Starting Firebase emulators ==="
  (cd "$REPO_ROOT" && firebase emulators:start --only auth,firestore,storage,functions) &
  EMULATOR_PID=$!

  echo "Waiting for emulators to start..."
  SECONDS=0
  until curl -sf "http://localhost:$AUTH_PORT/" >/dev/null 2>&1; do
    if [ $SECONDS -ge 60 ]; then
      echo "ERROR: Emulators did not start within 60 seconds"
      exit 1
    fi
    sleep 1
  done
  echo "Emulators are ready (took ${SECONDS}s)"
fi

echo "=== Pre-commit: flutter test (integration tests) ==="
(cd "$REPO_ROOT" && flutter test integration_test/)

echo "=== All checks passed ==="
