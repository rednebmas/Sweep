#!/bin/bash
# Update a field on a Sweep user document in Firestore
# Usage: ./update-user.sh <doc_id> <field> <type> <value>
# Types: string, boolean, integer
# Example: ./update-user.sh "rednebmas@gmail.com_gmail" apnsSandbox boolean true

set -e

DOC_ID="$1"
FIELD="$2"
TYPE="$3"
VALUE="$4"
PROJECT_ID="${SWEEP_PROJECT_ID:-sweep-483918}"

if [ -z "$DOC_ID" ] || [ -z "$FIELD" ] || [ -z "$TYPE" ] || [ -z "$VALUE" ]; then
  echo "Usage: $0 <doc_id> <field> <type> <value>"
  echo "Types: string, boolean, integer"
  exit 1
fi

TOKEN=$(gcloud auth print-access-token 2>/dev/null)
BASE="https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/users/$DOC_ID"

case "$TYPE" in
  string)  JSON_VALUE="{\"stringValue\": \"$VALUE\"}" ;;
  boolean) JSON_VALUE="{\"booleanValue\": $VALUE}" ;;
  integer) JSON_VALUE="{\"integerValue\": \"$VALUE\"}" ;;
  *) echo "Unknown type: $TYPE (use string, boolean, or integer)"; exit 1 ;;
esac

RESULT=$(curl -s -X PATCH \
  "$BASE?updateMask.fieldPaths=$FIELD" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"fields\": {\"$FIELD\": $JSON_VALUE}}")

if echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); sys.exit(0 if 'name' in d else 1)" 2>/dev/null; then
  echo "Updated $DOC_ID: $FIELD=$VALUE"
else
  echo "Error:"
  echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"
  exit 1
fi
