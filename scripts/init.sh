#!/bin/bash

# ==============================================================================
# GCP Terraform Bootstrap Script
# This script sets up APIs, State Bucket, Service Account, and Workload Identity
# Federation (WIF) for GitHub Actions.
# ==============================================================================

set -e  # Exit immediately if a command exits with a non-zero status

# --- 1. User Inputs ---
echo "----------------------------------------------------"
echo "🔧 GCP Bootstrap Configuration"
echo "----------------------------------------------------"

read -p "Enter your GCP Project ID: " PROJECT_ID
read -p "Enter your GitHub Repo (format: username/repo): " GITHUB_REPO
read -p "Enter GCP Region (default: us-east4): " REGION
REGION=${REGION:-us-east4}

BUCKET_NAME="${PROJECT_ID}-tfstate"
SERVICE_ACCOUNT_NAME="github-terraform"
POOL_NAME="github-pool"
PROVIDER_NAME="github-provider"

# --- 2. Authentication ---
# echo ""
# echo "🔐 checking authentication..."

# # Check if user is logged in, if not, trigger login
# if ! gcloud auth print-identity &>/dev/null; then
#     echo "Requesting gcloud login..."
#     gcloud auth login --no-launch-browser
# fi

# # Set the project context
# echo "Setting active project to $PROJECT_ID..."
# gcloud config set project "$PROJECT_ID"

# # Check Application Default Credentials (ADC)
# if [ ! -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
#     echo "Setting up Application Default Credentials..."
#     gcloud auth application-default login --no-launch-browser
# fi

# --- 3. Enable APIs ---
echo ""
echo "🚀 Enabling required APIs..."
gcloud services enable \
    firestore.googleapis.com \
    iam.googleapis.com \
    cloudresourcemanager.googleapis.com \
    iamcredentials.googleapis.com \
    sts.googleapis.com \
    serviceusage.googleapis.com \
    storage-api.googleapis.com

# --- 4. Create Terraform State Bucket ---
echo ""
echo "📦 Configuring GCS Bucket for Terraform State..."

if ! gcloud storage buckets describe "gs://$BUCKET_NAME" &>/dev/null; then
    gcloud storage buckets create "gs://$BUCKET_NAME" --location="$REGION"
    echo "Bucket $BUCKET_NAME created."
else
    echo "Bucket $BUCKET_NAME already exists."
fi

# Enable Versioning (Best Practice)
gcloud storage buckets update "gs://$BUCKET_NAME" --versioning

# --- 5. Service Account Setup ---
echo ""
echo "🤖 Setting up Service Account..."

SA_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
        --description="Service Account for Terraform GitHub Actions" \
        --display-name="Terraform Runner"
    echo "Service Account created."
else
    echo "Service Account already exists."
fi

echo "Assigning IAM roles..."
ROLES=("roles/editor" "roles/datastore.owner" "roles/storage.admin" "roles/iam.workloadIdentityUser")

for ROLE in "${ROLES[@]}"; do
    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="$ROLE" \
        --condition=None &>/dev/null
done

# --- 6. Workload Identity Federation (WIF) ---
echo ""
echo "🔗 Configuring Workload Identity Federation..."

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# Create Pool
if ! gcloud iam workload-identity-pools describe "$POOL_NAME" --location="global" &>/dev/null; then
    gcloud iam workload-identity-pools create "$POOL_NAME" \
        --location="global" \
        --display-name="GitHub Actions Pool"
    echo "Pool created."
else
    echo "Pool already exists."
fi

# Create Provider
if ! gcloud iam workload-identity-pools providers describe "$PROVIDER_NAME" --location="global" --workload-identity-pool="$POOL_NAME" &>/dev/null; then
    echo "Creating OIDC Provider..."
    gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_NAME" \
        --location="global" \
        --workload-identity-pool="$POOL_NAME" \
        --display-name="GitHub Provider" \
        --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
        --attribute-condition="assertion.repository=='$GITHUB_REPO'" \
        --issuer-uri="https://token.actions.githubusercontent.com"
    echo "Provider created successfully."
else
    echo "Provider already exists."
fi

# --- 7. Bind GitHub Repo to Service Account ---
echo ""
echo "🤝 Binding GitHub Repo to Service Account..."

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$POOL_NAME/attribute.repository/$GITHUB_REPO" \
    --condition=None &>/dev/null

# --- 8. Generate Output ---
PROVIDER_FULL_PATH=$(gcloud iam workload-identity-pools providers describe "$PROVIDER_NAME" \
    --location="global" \
    --workload-identity-pool="$POOL_NAME" \
    --format="value(name)")

echo ""
echo "===================================================="
echo "✅ Setup Complete!"
echo "===================================================="
echo "Update your .github/workflows/terraform.yml with these values:"
echo ""
echo "WIF_PROVIDER:        $PROVIDER_FULL_PATH"
echo "WIF_SERVICE_ACCOUNT: $SA_EMAIL"
echo "PROJECT_ID:          $PROJECT_ID"
echo "===================================================="