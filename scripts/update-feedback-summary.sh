#!/bin/bash
#
# Posts an AI summary to a feedback item via the Cloud Function.
#
# Usage:
#   ./scripts/update-feedback-summary.sh <REFERENCE_ID> "<SUMMARY>"
#
# Example:
#   ./scripts/update-feedback-summary.sh WISH-0003 "Added recipe tag management with autocomplete. Tags are stored as a list field on the recipe document."
#
# Prerequisites:
#   1. Set the secret in Firebase:  firebase functions:secrets:set FEEDBACK_API_KEY
#   2. Deploy functions:            cd personal_app && firebase deploy --only functions
#   3. Create local key file:       echo "your-key" > scripts/.feedback-api-key
#      (This file is gitignored)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KEY_FILE="$SCRIPT_DIR/.feedback-api-key"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <REFERENCE_ID> <SUMMARY>"
  echo "Example: $0 WISH-0003 \"Added recipe tag management\""
  exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
  echo "Error: API key file not found at $KEY_FILE"
  echo "Create it with: echo \"your-key\" > $KEY_FILE"
  exit 1
fi

API_KEY=$(cat "$KEY_FILE" | tr -d '[:space:]')
REF_ID="$1"
SUMMARY="$2"

FUNCTION_URL="https://us-central1-freek-personal-app.cloudfunctions.net/updateFeedbackSummary"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$FUNCTION_URL" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg ref "$REF_ID" --arg sum "$SUMMARY" '{referenceId: $ref, summary: $sum}')")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | head -n -1)

if [ "$HTTP_CODE" -eq 200 ]; then
  echo "✅ Updated $REF_ID"
  echo "$BODY"
else
  echo "❌ Failed (HTTP $HTTP_CODE)"
  echo "$BODY"
  exit 1
fi
