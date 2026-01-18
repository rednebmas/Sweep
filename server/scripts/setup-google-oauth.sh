#!/bin/bash
set -e

PROJECT_ID="${SWEEP_PROJECT_ID:-sweep-483918}"
CLIENT_ID="${1:-}"
CLIENT_SECRET="${2:-}"

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
  echo "Usage: ./setup-google-oauth.sh <client-id> <client-secret>"
  echo ""
  echo "Use the same OAuth credentials as your iOS app."
  echo "Find these in Google Cloud Console > APIs & Services > Credentials"
  exit 1
fi

gcloud config set project "$PROJECT_ID"
SERVICE_ACCOUNT="$PROJECT_ID@appspot.gserviceaccount.com"

echo "Storing Google Client ID..."
echo -n "$CLIENT_ID" | gcloud secrets create google-client-id --data-file=- 2>/dev/null || \
  echo -n "$CLIENT_ID" | gcloud secrets versions add google-client-id --data-file=-

gcloud secrets add-iam-policy-binding google-client-id \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

echo "Storing Google Client Secret..."
echo -n "$CLIENT_SECRET" | gcloud secrets create google-client-secret --data-file=- 2>/dev/null || \
  echo -n "$CLIENT_SECRET" | gcloud secrets versions add google-client-secret --data-file=-

gcloud secrets add-iam-policy-binding google-client-secret \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

echo ""
echo "Google OAuth credentials configured!"
