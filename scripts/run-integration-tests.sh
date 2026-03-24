#!/usr/bin/env bash
# Starts Firebase emulators, runs integration tests, then stops emulators.
#
# Usage:
#   bash scripts/run-integration-tests.sh
#
# Prerequisites:
#   - Firebase CLI installed (npm install -g firebase-tools)
#   - Java runtime (required by Firestore emulator)

set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
APP_DIR="$REPO_ROOT/personal_app"

# Ports used by emulators (must match firebase.json and firebase_test_setup.dart)
AUTH_PORT=9099
FIRESTORE_PORT=8080

cleanup() {
  echo ""
  echo "=== Stopping Firebase emulators ==="
  if [ -n "$EMULATOR_PID" ]; then
    kill "$EMULATOR_PID" 2>/dev/null || true
    wait "$EMULATOR_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Check if emulators are already running
if curl -sf "http://localhost:$AUTH_PORT/" >/dev/null 2>&1; then
  echo "=== Firebase emulators already running ==="
  EMULATOR_PID=""
else
  echo "=== Starting Firebase emulators ==="
  (cd "$APP_DIR" && firebase emulators:start --only auth,firestore,storage,functions) &
  EMULATOR_PID=$!

  # Wait for emulators to be ready (timeout after 60s)
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

echo ""
echo "=== Running integration tests ==="
(cd "$APP_DIR" && flutter test integration_test/)
