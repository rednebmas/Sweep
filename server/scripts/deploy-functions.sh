#!/bin/bash
set -e

PROJECT_ID="${SWEEP_PROJECT_ID:-sweep-push}"
REGION="${SWEEP_REGION:-us-central1}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FUNCTIONS_DIR="$SCRIPT_DIR/../functions"

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
  --set-secrets="APNS_KEY=apns-key:latest,SWEEP_API_KEY=sweep-api-key:latest"

echo "Deploying registerDevice (HTTP)..."
gcloud functions deploy registerDevice \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=registerDevice \
  --set-secrets="SWEEP_API_KEY=sweep-api-key:latest"

echo "Deploying appOpened (HTTP)..."
gcloud functions deploy appOpened \
  --gen2 \
  --runtime=nodejs20 \
  --region="$REGION" \
  --source="$FUNCTIONS_DIR" \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point=appOpened \
  --set-secrets="SWEEP_API_KEY=sweep-api-key:latest"

echo ""
echo "Deployment complete!"
echo ""
echo "Function URLs:"
gcloud functions describe registerDevice --region="$REGION" --format="value(serviceConfig.uri)"
gcloud functions describe appOpened --region="$REGION" --format="value(serviceConfig.uri)"
