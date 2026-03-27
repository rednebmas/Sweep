#!/bin/bash
# List all registered Sweep users from Firestore
# Usage: ./list-users.sh [--json]

PROJECT_ID="${SWEEP_PROJECT_ID:-sweep-483918}"
TOKEN=$(gcloud auth print-access-token 2>/dev/null)

RAW=$(curl -s \
  "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/users" \
  -H "Authorization: Bearer $TOKEN")

if [ "$1" = "--json" ]; then
  echo "$RAW" | python3 -m json.tool
  exit 0
fi

echo "$RAW" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for doc in data.get('documents', []):
    name = doc.get('name', '').split('/')[-1]
    fields = doc.get('fields', {})
    provider = fields.get('provider', {}).get('stringValue', '?')
    sandbox = fields.get('apnsSandbox', {}).get('booleanValue', 'unset')
    token = fields.get('deviceToken', {}).get('stringValue', '?')[:20]
    pending = len(fields.get('pendingEmails', {}).get('arrayValue', {}).get('values', []))
    print(f'{name}')
    print(f'  provider={provider}  apnsSandbox={sandbox}  pending={pending}')
    print(f'  token={token}...')
    print()
"
