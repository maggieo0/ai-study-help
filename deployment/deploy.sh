#!/bin/bash

# AI Study Buddy - GCP Deployment Script
# This script deploys the entire application to Google Cloud Platform

set -e  # Exit on error

echo "AI Study Buddy - Deployment Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed${NC}"
    echo "Install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get project ID
echo -e "${YELLOW}Step 1: Configure Google Cloud Project${NC}"
read -p "Enter your GCP Project ID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID cannot be empty${NC}"
    exit 1
fi

gcloud config set project $PROJECT_ID

echo -e "${GREEN}✓ Project set to: $PROJECT_ID${NC}"
echo ""

# Enable required APIs
echo -e "${YELLOW}Step 2: Enabling required Google Cloud APIs...${NC}"
echo "This may take a few minutes..."

gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable aiplatform.googleapis.com
gcloud services enable storage.googleapis.com

echo -e "${GREEN}✓ APIs enabled${NC}"
echo ""

# Deploy Cloud Function
echo -e "${YELLOW}Step 3: Deploying Cloud Function (Backend)...${NC}"

cd backend

gcloud functions deploy ai-study-help-generate \
    --gen2 \
    --runtime=python311 \
    --region=us-central1 \
    --source=. \
    --entry-point=generate \
    --trigger-http \
    --allow-unauthenticated \
    --set-env-vars GCP_PROJECT_ID=$PROJECT_ID \
    --memory=512MB \
    --timeout=540s

cd ..

echo -e "${GREEN}✓ Cloud Function deployed${NC}"
echo ""

# Get the function URL
FUNCTION_URL=$(gcloud functions describe ai-study-help-generate --gen2 --region=us-central1 --format='value(serviceConfig.uri)')

echo -e "${GREEN}Your Cloud Function URL: $FUNCTION_URL${NC}"
echo ""

# Create storage bucket for frontend
echo -e "${YELLOW}Step 4: Creating Cloud Storage bucket for website...${NC}"

BUCKET_NAME="${PROJECT_ID}-study-buddy"

# Check if bucket exists
if gsutil ls -b gs://$BUCKET_NAME &> /dev/null; then
    echo "Bucket already exists, using existing bucket"
else
    gsutil mb -l us-central1 gs://$BUCKET_NAME
    echo -e "${GREEN}✓ Bucket created${NC}"
fi

# Make bucket public
gsutil iam ch allUsers:objectViewer gs://$BUCKET_NAME

# Update index.html with function URL
echo -e "${YELLOW}Step 5: Updating frontend with API URL...${NC}"

sed -i "s|YOUR_CLOUD_FUNCTION_URL_HERE|$FUNCTION_URL|g" frontend/index.html

echo -e "${GREEN}✓ Frontend configured${NC}"
echo ""

# Upload frontend to bucket
echo -e "${YELLOW}Step 6: Uploading website files...${NC}"

gsutil cp frontend/index.html gs://$BUCKET_NAME/
gsutil setmeta -h "Content-Type:text/html" -h "Cache-Control:public, max-age=3600" gs://$BUCKET_NAME/index.html

echo -e "${GREEN}✓ Website uploaded${NC}"
echo ""

# Configure bucket for website hosting
gsutil web set -m index.html gs://$BUCKET_NAME

WEBSITE_URL="https://storage.googleapis.com/$BUCKET_NAME/index.html"

echo ""
echo "======================================"
echo -e "${GREEN} Deployment Complete!${NC}"
echo "======================================"
echo ""
echo -e "${GREEN}Your AI Study Buddy is live at:${NC}"
echo -e "${YELLOW}$WEBSITE_URL${NC}"
echo ""
echo "Next Steps:"
echo "1. Visit the URL above to test your app"
echo "2. Share it with students!"
echo "3. Monitor usage in GCP Console"
echo ""
echo "Cost Information:"
echo "- Cloud Functions: First 2M invocations/month FREE"
echo "- Vertex AI (Gemini): Pay per use, very low for student use"
echo "- Cloud Storage: $0.026/GB/month"
echo ""
echo "Useful Commands:"
echo "  View logs:    gcloud functions logs read ai-study-help-generate --region=us-central1"
echo "  Delete app:   ./cleanup.sh"
echo ""
