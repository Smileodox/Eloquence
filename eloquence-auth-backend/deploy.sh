#!/bin/bash
# Azure App Service Deployment Script

echo "Starting deployment to Azure App Service..."

# Deploy the app (using existing location germanywestcentral)
az webapp up --name eloquence-auth-api --runtime PYTHON:3.11 --sku B1 --location germanywestcentral

echo "Deployment complete!"
