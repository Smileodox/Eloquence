#!/bin/bash
# Proper Azure App Service Deployment Script

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Deploying from directory: $SCRIPT_DIR"
echo "Creating deployment package from backend directory..."

# Change to backend directory
cd "$SCRIPT_DIR"

# Create zip file
zip -r deploy.zip app requirements.txt .env

# Deploy using Azure CLI zip deploy
az webapp deployment source config-zip --name eloquence-auth-api --resource-group eloquence --src "$SCRIPT_DIR/deploy.zip"

# Clean up
rm deploy.zip

echo "Deployment complete!"
