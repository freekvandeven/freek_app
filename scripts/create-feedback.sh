#!/bin/bash
#
# Creates a feedback item (bug / wish / improvement) directly in the
# user's feedback database via the createFeedback Cloud Function.
#
# Usage:
#   ./scripts/create-feedback.sh <TYPE> "<TITLE>" "<DESCRIPTION>"
#
# Where:
#   TYPE        is one of: bug | wish | improvement
#   TITLE       short one-line summary
#   DESCRIPTION longer description (can include newlines via $'...\n...')
#
# Example:
#   ./scripts/create-feedback.sh improvement \
#     "Drop unused google_generative_ai dependency" \
#     "After WISH-0067 the SDK is unused; removing it shaves ~few hundred KB off the web bundle."
#
# Prerequisites:
#   1. Set the secret in Firebase:  firebase functions:secrets:set FEEDBACK_API_KEY
#   2. Deploy functions:            firebase deploy --only functions
#   3. Create local key file:       echo "your-key" > scripts/.feedback-api-key
#      (gitignored)
#
# On success prints the assigned reference ID (e.g. IMPR-0001).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY_FILE="$SCRIPT_DIR/.feedback-api-key"

if [ $# -lt 3 ]; then
  echo "Usage: $0 <bug|wish|improvement> <TITLE> <DESCRIPTION>"
  echo "Example: $0 improvement \"Drop dead dep\" \"Removes google_generative_ai...\""
  exit 1
fi

TYPE="$1"
TITLE="$2"
DESCRIPTION="$3"

case "$TYPE" in
  bug|wish|improvement) ;;
  *)
    echo "Error: TYPE must be one of bug | wish | improvement (got: $TYPE)"
    exit 1
    ;;
esac

if [ ! -f "$KEY_FILE" ]; then
  echo "Error: API key file not found at $KEY_FILE"
  echo "Create it with: echo \"your-key\" > $KEY_FILE"
  exit 1
fi

API_KEY=$(cat "$KEY_FILE" | tr -d '[:space:]')
FUNCTION_URL="https://europe-west4-freek-personal-app.cloudfunctions.net/createFeedback"

# Build JSON payload. Use jq when available for safe escaping.
if command -v jq &>/dev/null; then
  JSON_BODY=$(jq -n \
    --arg type "$TYPE" \
    --arg title "$TITLE" \
    --arg desc "$DESCRIPTION" \
    '{type: $type, title: $title, description: $desc}')
else
  escape_json() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g'
  }
  JSON_BODY="{\"type\":\"$(escape_json "$TYPE")\",\"title\":\"$(escape_json "$TITLE")\",\"description\":\"$(escape_json "$DESCRIPTION")\"}"
fi

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$JSON_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" -eq 200 ]; then
  if command -v jq &>/dev/null; then
    REF=$(echo "$BODY" | jq -r '.referenceId')
    echo "✅ Created $REF"
  else
    echo "✅ Created"
  fi
  echo "$BODY"
else
  echo "❌ Failed (HTTP $HTTP_CODE)"
  echo "$BODY"
  exit 1
fi
