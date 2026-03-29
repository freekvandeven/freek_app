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

# Ports used by emulators (must match firebase.json and firebase_test_setup.dart)
AUTH_PORT=9099
FIRESTORE_PORT=8080

# Firestore emulator requires Java
if ! command -v java &>/dev/null; then
  echo "ERROR: Java is required for the Firestore emulator but was not found."
  echo "Install a JDK (e.g. temurin-21) and ensure 'java' is on your PATH."
  exit 1
fi

cleanup() {
  echo ""
  echo "=== Stopping Firebase emulators ==="
  if [ -n "$EMULATOR_PID" ]; then
    kill "$EMULATOR_PID" 2>/dev/null || true
    wait "$EMULATOR_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Build Cloud Functions so the functions emulator can load them
echo "=== Building Cloud Functions ==="
(cd "$REPO_ROOT/functions" && npm run build)

# Check if emulators are already running
if curl -sf "http://localhost:$AUTH_PORT/" >/dev/null 2>&1; then
  echo "=== Firebase emulators already running ==="
  EMULATOR_PID=""
else
  echo "=== Starting Firebase emulators ==="
  (cd "$REPO_ROOT" && firebase emulators:start --only auth,firestore,storage,functions) &
  EMULATOR_PID=$!

  # Wait for both Auth and Firestore emulators to be ready (timeout after 90s)
  echo "Waiting for emulators to start..."
  SECONDS=0
  until curl -sf "http://localhost:$AUTH_PORT/" >/dev/null 2>&1 \
     && curl -sf "http://localhost:$FIRESTORE_PORT/" >/dev/null 2>&1; do
    if [ $SECONDS -ge 90 ]; then
      echo "ERROR: Emulators did not start within 90 seconds"
      exit 1
    fi
    # Check if the emulator process died
    if ! kill -0 "$EMULATOR_PID" 2>/dev/null; then
      echo "ERROR: Emulator process exited unexpectedly"
      exit 1
    fi
    sleep 2
  done
  echo "Emulators are ready (took ${SECONDS}s)"
fi

echo ""
echo "=== Running integration tests ==="
(cd "$REPO_ROOT" && flutter test integration_test/)
