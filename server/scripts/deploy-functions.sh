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
  --set-env-vars="OUTLOOK_WEBHOOK_URL=$OUTLOOK_WEBHOOK_URL,GCP_PROJECT=$PROJECT_ID" \
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
  --set-secrets="APNS_KEY=apns-key:latest,APNS_TEAM_ID=apns-team-id:latest,APNS_KEY_ID=apns-key-id:latest,OUTLOOK_CLIENT_STATE=outlook-client-state:latest,AZURE_CLIENT_ID=azure-client-id:latest,AZURE_CLIENT_SECRET=azure-client-secret:latest"

echo "Deploying pollIMAPAccounts (HTTP, hourly via Cloud Scheduler)..."
gcloud functions deploy pollIMAPAccounts \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=pollIMAPAccounts \
  --set-env-vars="GCP_PROJECT=$PROJECT_ID" \
  --set-secrets="SWEEP_API_KEY=sweep-api-key:latest,APNS_KEY=apns-key:latest,APNS_TEAM_ID=apns-team-id:latest,APNS_KEY_ID=apns-key-id:latest"

echo "Deploying renewWatches (HTTP, daily via Cloud Scheduler)..."
gcloud functions deploy renewWatches \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=renewWatches \
  --set-env-vars="GCP_PROJECT=$PROJECT_ID,OUTLOOK_WEBHOOK_URL=$OUTLOOK_WEBHOOK_URL" \
  --set-secrets="SWEEP_API_KEY=sweep-api-key:latest,APNS_KEY=apns-key:latest,APNS_TEAM_ID=apns-team-id:latest,APNS_KEY_ID=apns-key-id:latest,GOOGLE_CLIENT_ID=google-client-id:latest,GOOGLE_CLIENT_SECRET=google-client-secret:latest,AZURE_CLIENT_ID=azure-client-id:latest,AZURE_CLIENT_SECRET=azure-client-secret:latest,OUTLOOK_CLIENT_STATE=outlook-client-state:latest"

echo "Configuring daily Cloud Scheduler job for renewWatches..."
RENEW_URL=$(gcloud functions describe renewWatches --region="$REGION" --format="value(serviceConfig.uri)")
SWEEP_API_KEY_VALUE=$(gcloud secrets versions access latest --secret=sweep-api-key)

if gcloud scheduler jobs describe renew-watches-daily --location="$REGION" >/dev/null 2>&1; then
  SCHED_CMD=update
else
  SCHED_CMD=create
fi
gcloud scheduler jobs "$SCHED_CMD" http renew-watches-daily \
  --location="$REGION" \
  --schedule="0 10 * * *" \
  --time-zone="Etc/UTC" \
  --uri="$RENEW_URL" \
  --http-method=POST \
  --headers="x-sweep-key=$SWEEP_API_KEY_VALUE,Content-Type=application/json" \
  --message-body='{}' \
  --attempt-deadline=540s

echo ""
echo "Deployment complete!"
echo ""
echo "Function URLs:"
gcloud functions describe registerDevice --region="$REGION" --format="value(serviceConfig.uri)"
gcloud functions describe appOpened --region="$REGION" --format="value(serviceConfig.uri)"
gcloud functions describe onOutlookNotification --region="$REGION" --format="value(serviceConfig.uri)"
gcloud functions describe pollIMAPAccounts --region="$REGION" --format="value(serviceConfig.uri)"
gcloud functions describe renewWatches --region="$REGION" --format="value(serviceConfig.uri)"
