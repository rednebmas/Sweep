#!/bin/bash
set -e

PROJECT_ID="${SWEEP_PROJECT_ID:-sweep-push}"
APNS_KEY_FILE="${1:-}"
APNS_TEAM_ID="${2:-}"
APNS_KEY_ID="${3:-}"

if [ -z "$APNS_KEY_FILE" ] || [ -z "$APNS_TEAM_ID" ] || [ -z "$APNS_KEY_ID" ]; then
  echo "Usage: ./setup-secrets.sh <apns-key.p8> <team-id> <key-id>"
  echo ""
  echo "Arguments:"
  echo "  apns-key.p8  - APNs auth key file from Apple Developer Portal"
  echo "  team-id      - Your Apple Developer Team ID (10 chars)"
  echo "  key-id       - The Key ID for your APNs key (10 chars)"
  echo ""
  echo "Get these from Apple Developer Portal:"
  echo "  Certificates, Identifiers & Profiles > Keys"
  exit 1
fi

if [ ! -f "$APNS_KEY_FILE" ]; then
  echo "Error: APNs key file not found: $APNS_KEY_FILE"
  exit 1
fi

gcloud config set project "$PROJECT_ID"
SERVICE_ACCOUNT="$PROJECT_ID@appspot.gserviceaccount.com"

echo "Storing APNs key..."
gcloud secrets create apns-key --data-file="$APNS_KEY_FILE" 2>/dev/null || \
  gcloud secrets versions add apns-key --data-file="$APNS_KEY_FILE"

gcloud secrets add-iam-policy-binding apns-key \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

echo "Storing APNs Team ID..."
echo -n "$APNS_TEAM_ID" | gcloud secrets create apns-team-id --data-file=- 2>/dev/null || \
  echo -n "$APNS_TEAM_ID" | gcloud secrets versions add apns-team-id --data-file=-

gcloud secrets add-iam-policy-binding apns-team-id \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

echo "Storing APNs Key ID..."
echo -n "$APNS_KEY_ID" | gcloud secrets create apns-key-id --data-file=- 2>/dev/null || \
  echo -n "$APNS_KEY_ID" | gcloud secrets versions add apns-key-id --data-file=-

gcloud secrets add-iam-policy-binding apns-key-id \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

echo "Generating API secret..."
API_SECRET=$(openssl rand -base64 32)
echo -n "$API_SECRET" | gcloud secrets create sweep-api-key --data-file=- 2>/dev/null || \
  echo -n "$API_SECRET" | gcloud secrets versions add sweep-api-key --data-file=-

gcloud secrets add-iam-policy-binding sweep-api-key \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor" \
  --quiet

echo ""
echo "Secrets configured!"
echo ""
echo "API Secret (add to iOS app):"
echo "$API_SECRET"
echo ""
echo "Save this secret - it won't be shown again."
