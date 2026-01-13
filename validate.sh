#!/bin/bash
# Validate ZavaStorefront Infrastructure Deployment
# This script checks that all resources are properly deployed and configured

set -e

RESOURCE_GROUP="rg-zavastore-dev-westus3"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== ZavaStorefront Infrastructure Validation ===${NC}"
echo ""

# Check if resource group exists
echo -e "${YELLOW}1. Checking resource group...${NC}"
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    echo -e "${GREEN}✓ Resource group exists: $RESOURCE_GROUP${NC}"
else
    echo -e "${RED}✗ Resource group not found: $RESOURCE_GROUP${NC}"
    exit 1
fi
echo ""

# List all resources
echo -e "${YELLOW}2. Listing all resources...${NC}"
RESOURCE_COUNT=$(az resource list --resource-group "$RESOURCE_GROUP" --query "length(@)" -o tsv)
echo -e "${GREEN}✓ Found $RESOURCE_COUNT resources${NC}"
az resource list --resource-group "$RESOURCE_GROUP" --output table
echo ""

# Check Container Registry
echo -e "${YELLOW}3. Checking Container Registry...${NC}"
ACR_NAME=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -n "$ACR_NAME" ]; then
    echo -e "${GREEN}✓ ACR found: $ACR_NAME${NC}"
    ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
    echo -e "  Login Server: $ACR_LOGIN_SERVER"
    
    # Check if admin user is disabled
    ADMIN_ENABLED=$(az acr show --name "$ACR_NAME" --query adminUserEnabled -o tsv)
    if [ "$ADMIN_ENABLED" == "false" ]; then
        echo -e "${GREEN}  ✓ Admin user disabled (using managed identity)${NC}"
    else
        echo -e "${YELLOW}  ⚠ Admin user is enabled${NC}"
    fi
else
    echo -e "${RED}✗ ACR not found${NC}"
fi
echo ""

# Check App Service Plan
echo -e "${YELLOW}4. Checking App Service Plan...${NC}"
ASP_NAME=$(az appservice plan list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -n "$ASP_NAME" ]; then
    echo -e "${GREEN}✓ App Service Plan found: $ASP_NAME${NC}"
    ASP_SKU=$(az appservice plan show --name "$ASP_NAME" --resource-group "$RESOURCE_GROUP" --query "sku.name" -o tsv)
    echo -e "  SKU: $ASP_SKU"
else
    echo -e "${RED}✗ App Service Plan not found${NC}"
fi
echo ""

# Check Web App
echo -e "${YELLOW}5. Checking Web App...${NC}"
WEBAPP_NAME=$(az webapp list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -n "$WEBAPP_NAME" ]; then
    echo -e "${GREEN}✓ Web App found: $WEBAPP_NAME${NC}"
    
    WEBAPP_URL=$(az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --query defaultHostName -o tsv)
    echo -e "  URL: https://$WEBAPP_URL"
    
    # Check if managed identity is enabled
    IDENTITY_TYPE=$(az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --query "identity.type" -o tsv)
    if [ "$IDENTITY_TYPE" == "SystemAssigned" ]; then
        echo -e "${GREEN}  ✓ System-assigned managed identity enabled${NC}"
        PRINCIPAL_ID=$(az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --query "identity.principalId" -o tsv)
        echo -e "  Principal ID: $PRINCIPAL_ID"
    else
        echo -e "${RED}  ✗ Managed identity not configured${NC}"
    fi
    
    # Check HTTPS only
    HTTPS_ONLY=$(az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --query "httpsOnly" -o tsv)
    if [ "$HTTPS_ONLY" == "true" ]; then
        echo -e "${GREEN}  ✓ HTTPS only enabled${NC}"
    else
        echo -e "${YELLOW}  ⚠ HTTPS only not enabled${NC}"
    fi
else
    echo -e "${RED}✗ Web App not found${NC}"
fi
echo ""

# Check role assignments
echo -e "${YELLOW}6. Checking role assignments...${NC}"
if [ -n "$WEBAPP_NAME" ] && [ -n "$ACR_NAME" ]; then
    PRINCIPAL_ID=$(az webapp show --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP" --query "identity.principalId" -o tsv)
    
    ROLE_ASSIGNMENTS=$(az role assignment list --assignee "$PRINCIPAL_ID" --query "[?roleDefinitionName=='AcrPull'].roleDefinitionName" -o tsv)
    if [ -n "$ROLE_ASSIGNMENTS" ]; then
        echo -e "${GREEN}✓ AcrPull role assigned to Web App managed identity${NC}"
    else
        echo -e "${RED}✗ AcrPull role not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping role assignment check${NC}"
fi
echo ""

# Check Application Insights
echo -e "${YELLOW}7. Checking Application Insights...${NC}"
APPINSIGHTS_NAME=$(az monitor app-insights component list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -n "$APPINSIGHTS_NAME" ]; then
    echo -e "${GREEN}✓ Application Insights found: $APPINSIGHTS_NAME${NC}"
    INSTRUMENTATION_KEY=$(az monitor app-insights component show --app "$APPINSIGHTS_NAME" --resource-group "$RESOURCE_GROUP" --query "instrumentationKey" -o tsv)
    echo -e "  Instrumentation Key: ${INSTRUMENTATION_KEY:0:8}...${INSTRUMENTATION_KEY:(-8)}"
else
    echo -e "${RED}✗ Application Insights not found${NC}"
fi
echo ""

# Check Log Analytics Workspace
echo -e "${YELLOW}8. Checking Log Analytics Workspace...${NC}"
LOG_WORKSPACE=$(az monitor log-analytics workspace list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -n "$LOG_WORKSPACE" ]; then
    echo -e "${GREEN}✓ Log Analytics Workspace found: $LOG_WORKSPACE${NC}"
else
    echo -e "${RED}✗ Log Analytics Workspace not found${NC}"
fi
echo ""

# Check Storage Account
echo -e "${YELLOW}9. Checking Storage Account...${NC}"
STORAGE_NAME=$(az storage account list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -n "$STORAGE_NAME" ]; then
    echo -e "${GREEN}✓ Storage Account found: $STORAGE_NAME${NC}"
    
    # Check TLS version
    TLS_VERSION=$(az storage account show --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" --query "minimumTlsVersion" -o tsv)
    echo -e "  Minimum TLS Version: $TLS_VERSION"
    
    # Check public blob access
    PUBLIC_ACCESS=$(az storage account show --name "$STORAGE_NAME" --resource-group "$RESOURCE_GROUP" --query "allowBlobPublicAccess" -o tsv)
    if [ "$PUBLIC_ACCESS" == "false" ]; then
        echo -e "${GREEN}  ✓ Public blob access disabled${NC}"
    else
        echo -e "${YELLOW}  ⚠ Public blob access enabled${NC}"
    fi
else
    echo -e "${RED}✗ Storage Account not found${NC}"
fi
echo ""

# Check Key Vault
echo -e "${YELLOW}10. Checking Key Vault...${NC}"
KV_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -n "$KV_NAME" ]; then
    echo -e "${GREEN}✓ Key Vault found: $KV_NAME${NC}"
    
    # Check RBAC authorization
    RBAC_ENABLED=$(az keyvault show --name "$KV_NAME" --resource-group "$RESOURCE_GROUP" --query "properties.enableRbacAuthorization" -o tsv)
    if [ "$RBAC_ENABLED" == "true" ]; then
        echo -e "${GREEN}  ✓ RBAC authorization enabled${NC}"
    else
        echo -e "${YELLOW}  ⚠ Using access policies instead of RBAC${NC}"
    fi
else
    echo -e "${RED}✗ Key Vault not found${NC}"
fi
echo ""

# Check AI Foundry Hub
echo -e "${YELLOW}11. Checking AI Foundry Hub...${NC}"
AI_HUB=$(az ml workspace list --resource-group "$RESOURCE_GROUP" --query "[?kind=='Hub'].name" -o tsv)
if [ -n "$AI_HUB" ]; then
    echo -e "${GREEN}✓ AI Foundry Hub found: $AI_HUB${NC}"
else
    echo -e "${YELLOW}⚠ AI Foundry Hub not found${NC}"
fi
echo ""

# Check AI Foundry Project
echo -e "${YELLOW}12. Checking AI Foundry Project...${NC}"
AI_PROJECT=$(az ml workspace list --resource-group "$RESOURCE_GROUP" --query "[?kind=='Project'].name" -o tsv)
if [ -n "$AI_PROJECT" ]; then
    echo -e "${GREEN}✓ AI Foundry Project found: $AI_PROJECT${NC}"
else
    echo -e "${YELLOW}⚠ AI Foundry Project not found${NC}"
fi
echo ""

# Test Web App connectivity
echo -e "${YELLOW}13. Testing Web App connectivity...${NC}"
if [ -n "$WEBAPP_URL" ]; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$WEBAPP_URL" || echo "000")
    if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 400 ]; then
        echo -e "${GREEN}✓ Web App is responding (HTTP $HTTP_STATUS)${NC}"
    else
        echo -e "${YELLOW}⚠ Web App returned HTTP $HTTP_STATUS (may still be starting)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Skipping connectivity test${NC}"
fi
echo ""

echo -e "${GREEN}=== Validation Complete ===${NC}"
echo ""
echo -e "Summary:"
echo -e "  Resource Group:     ${GREEN}$RESOURCE_GROUP${NC}"
echo -e "  Total Resources:    ${GREEN}$RESOURCE_COUNT${NC}"
echo -e "  Web App URL:        ${GREEN}https://$WEBAPP_URL${NC}"
echo ""
