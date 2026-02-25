#!/bin/bash

# AI Study Help - Cleanup Script
# Removes all deployed resources from Google Cloud

set -e

echo "AI Study Help - Cleanup Script"
echo "======================================"
echo ""

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

read -p "Enter your GCP Project ID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: Project ID cannot be empty${NC}"
    exit 1
fi

gcloud config set project $PROJECT_ID

echo ""
echo -e "${YELLOW}This will delete:${NC}"
echo "  - Cloud Function: ai-study-buddy-generate"
echo "  - Storage Bucket: ${PROJECT_ID}-study-buddy"
echo ""

read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting Cloud Function...${NC}"
gcloud functions delete ai-study-buddy-generate --region=us-central1 --gen2 --quiet || true
echo -e "${GREEN}✓ Cloud Function deleted${NC}"

echo ""
echo -e "${YELLOW}Deleting Storage Bucket...${NC}"
gsutil -m rm -r gs://${PROJECT_ID}-study-buddy || true
echo -e "${GREEN}✓ Storage Bucket deleted${NC}"

echo ""
echo -e "${GREEN}✓ Cleanup complete!${NC}"
echo ""
