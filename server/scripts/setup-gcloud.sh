#!/bin/bash
set -e

PROJECT_ID="${SWEEP_PROJECT_ID:-sweep-483918}"
REGION="${SWEEP_REGION:-us-central1}"

echo "Setting up GCloud project: $PROJECT_ID"

gcloud projects create "$PROJECT_ID" --name="Sweep Push" 2>/dev/null || echo "Project already exists"
gcloud config set project "$PROJECT_ID"

echo "Enabling APIs..."
gcloud services enable \
  cloudfunctions.googleapis.com \
  pubsub.googleapis.com \
  firestore.googleapis.com \
  gmail.googleapis.com \
  secretmanager.googleapis.com

echo "Creating Pub/Sub topic..."
gcloud pubsub topics create gmail-notifications 2>/dev/null || echo "Topic already exists"

echo "Granting Gmail permission to publish..."
gcloud pubsub topics add-iam-policy-binding gmail-notifications \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher"

echo "Creating Firestore database..."
gcloud firestore databases create --location="$REGION" 2>/dev/null || echo "Firestore already exists"

echo ""
echo "Setup complete!"
echo "Next steps:"
echo "  1. Run ./setup-secrets.sh to configure APNs key and API secret"
echo "  2. Run ./deploy-functions.sh to deploy Cloud Functions"
