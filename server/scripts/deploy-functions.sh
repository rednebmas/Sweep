#!/bin/bash
set -e

PROJECT_ID="${SWEEP_PROJECT_ID:-sweep-483918}"
REGION="${SWEEP_REGION:-us-central1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FUNCTIONS_DIR="$SCRIPT_DIR/../functions"

echo "Building TypeScript..."
cd "$FUNCTIONS_DIR"
npm install
npm run build
cd - > /dev/null

gcloud config set project "$PROJECT_ID"

echo "Deploying Cloud Functions from $FUNCTIONS_DIR..."

echo "Deploying onGmailNotification (Pub/Sub trigger)..."
gcloud functions deploy onGmailNotification \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-topic=gmail-notifications \
  --entry-point=onGmailNotification \
  --set-env-vars="APNS_SANDBOX=true" \
  --set-secrets="APNS_KEY=apns-key:latest,APNS_TEAM_ID=apns-team-id:latest,APNS_KEY_ID=apns-key-id:latest,SWEEP_API_KEY=sweep-api-key:latest,GOOGLE_CLIENT_ID=google-client-id:latest,GOOGLE_CLIENT_SECRET=google-client-secret:latest"

OUTLOOK_WEBHOOK_URL="https://$REGION-$PROJECT_ID.cloudfunctions.net/onOutlookNotification"

echo "Deploying registerDevice (HTTP)..."
gcloud functions deploy registerDevice \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=registerDevice \
  --set-env-vars="OUTLOOK_WEBHOOK_URL=$OUTLOOK_WEBHOOK_URL" \
  --set-secrets="SWEEP_API_KEY=sweep-api-key:latest,GOOGLE_CLIENT_ID=google-client-id:latest,GOOGLE_CLIENT_SECRET=google-client-secret:latest,AZURE_CLIENT_ID=azure-client-id:latest,AZURE_CLIENT_SECRET=azure-client-secret:latest"

echo "Deploying appOpened (HTTP)..."
gcloud functions deploy appOpened \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=appOpened \
  --set-secrets="SWEEP_API_KEY=sweep-api-key:latest,GOOGLE_CLIENT_ID=google-client-id:latest,GOOGLE_CLIENT_SECRET=google-client-secret:latest,AZURE_CLIENT_ID=azure-client-id:latest,AZURE_CLIENT_SECRET=azure-client-secret:latest"

echo "Deploying onOutlookNotification (HTTP webhook)..."
gcloud functions deploy onOutlookNotification \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=onOutlookNotification \
  --set-env-vars="APNS_SANDBOX=true" \
  --set-secrets="APNS_KEY=apns-key:latest,APNS_TEAM_ID=apns-team-id:latest,APNS_KEY_ID=apns-key-id:latest,OUTLOOK_CLIENT_STATE=outlook-client-state:latest,AZURE_CLIENT_ID=azure-client-id:latest,AZURE_CLIENT_SECRET=azure-client-secret:latest"

echo ""
echo "Deployment complete!"
echo ""
echo "Function URLs:"
gcloud functions describe registerDevice --region="$REGION" --format="value(serviceConfig.uri)"
gcloud functions describe appOpened --region="$REGION" --format="value(serviceConfig.uri)"
gcloud functions describe onOutlookNotification --region="$REGION" --format="value(serviceConfig.uri)"
