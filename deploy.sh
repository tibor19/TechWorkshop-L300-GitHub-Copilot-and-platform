#!/bin/bash
# Deploy ZavaStorefront Infrastructure to Azure
# This script provisions all Azure resources using Bicep

set -e

# Configuration
RESOURCE_GROUP="rg-zavastore-dev-westus3"
LOCATION="westus3"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== ZavaStorefront Azure Infrastructure Deployment ===${NC}"
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}Error: Azure CLI is not installed.${NC}"
    echo "Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

echo -e "${GREEN}✓ Azure CLI found${NC}"

# Login check
echo -e "${YELLOW}Checking Azure authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}Not logged in. Running az login...${NC}"
    az login
fi

echo -e "${GREEN}✓ Authenticated${NC}"

# Set subscription if provided
if [ -n "$SUBSCRIPTION_ID" ]; then
    echo -e "${YELLOW}Setting subscription to: $SUBSCRIPTION_ID${NC}"
    az account set --subscription "$SUBSCRIPTION_ID"
fi

# Show current subscription
CURRENT_SUB=$(az account show --query name -o tsv)
echo -e "${GREEN}Using subscription: $CURRENT_SUB${NC}"
echo ""

# Create resource group
echo -e "${YELLOW}Creating resource group: $RESOURCE_GROUP in $LOCATION${NC}"
az group create \
    --name "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --output table

echo -e "${GREEN}✓ Resource group created${NC}"
echo ""

# Deploy infrastructure
echo -e "${YELLOW}Deploying infrastructure (this may take 10-15 minutes)...${NC}"
DEPLOYMENT_NAME="zavastorefront-$(date +%Y%m%d-%H%M%S)"

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --template-file infra/main.bicep \
    --parameters infra/main.bicepparam \
    --output table

echo -e "${GREEN}✓ Infrastructure deployed${NC}"
echo ""

# Get outputs
echo -e "${YELLOW}Retrieving deployment outputs...${NC}"
ACR_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.containerRegistryName.value -o tsv)

ACR_LOGIN_SERVER=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.containerRegistryLoginServer.value -o tsv)

WEBAPP_NAME=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.webAppName.value -o tsv)

WEBAPP_URL=$(az deployment group show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DEPLOYMENT_NAME" \
    --query properties.outputs.webAppUrl.value -o tsv)

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo -e "Resource Group:     ${GREEN}$RESOURCE_GROUP${NC}"
echo -e "ACR Name:           ${GREEN}$ACR_NAME${NC}"
echo -e "ACR Login Server:   ${GREEN}$ACR_LOGIN_SERVER${NC}"
echo -e "Web App Name:       ${GREEN}$WEBAPP_NAME${NC}"
echo -e "Web App URL:        ${GREEN}$WEBAPP_URL${NC}"
echo ""

# Build and push Docker image
echo -e "${YELLOW}Building and pushing Docker image to ACR...${NC}"
echo -e "${YELLOW}This uses cloud-based ACR build (no local Docker required)${NC}"

az acr build \
    --registry "$ACR_NAME" \
    --image zavastorefront:latest \
    --image "zavastorefront:$(date +%Y%m%d-%H%M%S)" \
    --file Dockerfile \
    ./src

echo -e "${GREEN}✓ Docker image built and pushed${NC}"
echo ""

# Update Web App to use the image
echo -e "${YELLOW}Updating Web App to use the new image...${NC}"
az webapp config container set \
    --name "$WEBAPP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --docker-custom-image-name "${ACR_LOGIN_SERVER}/zavastorefront:latest" \
    --docker-registry-server-url "https://${ACR_LOGIN_SERVER}" \
    --output table

echo -e "${GREEN}✓ Web App configured${NC}"
echo ""

# Restart Web App
echo -e "${YELLOW}Restarting Web App...${NC}"
az webapp restart \
    --name "$WEBAPP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --output table

echo -e "${GREEN}✓ Web App restarted${NC}"
echo ""

echo -e "${GREEN}=== Deployment Summary ===${NC}"
echo ""
echo -e "Your application should be available at:"
echo -e "${GREEN}$WEBAPP_URL${NC}"
echo ""
echo -e "It may take a few minutes for the application to start."
echo ""
echo -e "To view logs:"
echo -e "  az webapp log tail --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP"
echo ""
echo -e "To clean up all resources:"
echo -e "  az group delete --name $RESOURCE_GROUP --yes --no-wait"
echo ""
