# Testing and Validation Guide

This document outlines how to test and validate the ZavaStorefront infrastructure deployment.

## Prerequisites for Testing

Before running deployment tests, ensure you have:

1. **Azure Subscription**: Active subscription with sufficient credits
2. **Azure CLI**: Version 2.40.0 or later
3. **Bicep CLI**: Included with Azure CLI
4. **Permissions**: Contributor role on the subscription or resource group
5. **Quota Check**: Verify regional quotas for:
   - App Service Plans (B1 or higher)
   - Machine Learning workspaces (for AI Foundry)
   - Container Registry

## Pre-Deployment Validation

### 1. Validate Bicep Templates

```bash
# Validate main template
az bicep build --file infra/main.bicep

# Validate all modules
cd infra/modules
for file in *.bicep; do
    echo "Validating $file..."
    az bicep build --file "$file"
done
```

Expected result: No errors, only informational messages.

### 2. Perform What-If Analysis

```bash
# Login and set subscription
az login
az account set --subscription <subscription-id>

# Create resource group
az group create --name rg-zavastore-dev-westus3 --location westus3

# Run what-if to preview changes
az deployment group what-if \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

Expected result: List of resources to be created with no errors.

## Deployment Testing

### Option 1: Automated Deployment Script

```bash
# Run the deployment script
./deploy.sh
```

Monitor the output for:
- ✅ Azure CLI authentication
- ✅ Resource group creation
- ✅ Infrastructure deployment (10-15 minutes)
- ✅ Docker image build and push
- ✅ Web App configuration
- ✅ Final URL output

### Option 2: Manual Step-by-Step

```bash
# 1. Deploy infrastructure
az deployment group create \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --name zavastorefront-test-$(date +%Y%m%d-%H%M%S)

# 2. Verify deployment succeeded
az deployment group show \
  --resource-group rg-zavastore-dev-westus3 \
  --name <deployment-name> \
  --query properties.provisioningState

# Expected: "Succeeded"
```

## Post-Deployment Validation

### 1. Run Validation Script

```bash
./validate.sh
```

This script checks:
- ✅ Resource group exists
- ✅ All resources are created
- ✅ Container Registry configuration
- ✅ App Service Plan and Web App
- ✅ Managed identity enabled
- ✅ Role assignments (AcrPull)
- ✅ Application Insights configured
- ✅ Log Analytics Workspace
- ✅ Storage Account security settings
- ✅ Key Vault configuration
- ✅ AI Foundry Hub and Project
- ✅ Web App connectivity

### 2. Manual Verification Steps

#### Verify Container Registry

```bash
ACR_NAME=$(az acr list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)

# Check admin user is disabled
az acr show --name $ACR_NAME --query adminUserEnabled
# Expected: false

# List images
az acr repository list --name $ACR_NAME
# Expected: ["zavastorefront"]
```

#### Verify Web App

```bash
WEBAPP_NAME=$(az webapp list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)

# Check managed identity
az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query identity.type
# Expected: "SystemAssigned"

# Check HTTPS only
az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query httpsOnly
# Expected: true

# Get Web App URL
WEBAPP_URL=$(az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query defaultHostName -o tsv)
echo "https://$WEBAPP_URL"
```

#### Verify Role Assignments

```bash
# Get Web App managed identity principal ID
PRINCIPAL_ID=$(az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query identity.principalId -o tsv)

# List role assignments
az role assignment list --assignee $PRINCIPAL_ID --output table
# Expected: Should include "AcrPull" role on ACR
```

#### Verify Application Insights

```bash
APPINSIGHTS_NAME=$(az monitor app-insights component list \
  --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)

# Check if linked to Web App
az webapp config appsettings list --name $WEBAPP_NAME \
  --resource-group rg-zavastore-dev-westus3 \
  --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"
# Expected: Connection string should be present
```

#### Verify AI Foundry Resources

```bash
# List ML workspaces (Hub and Project)
az ml workspace list --resource-group rg-zavastore-dev-westus3 --output table

# Expected: Two workspaces - one Hub, one Project
```

### 3. Test Application Functionality

#### Test Web App Availability

```bash
# Get Web App URL
WEBAPP_URL=$(az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query defaultHostName -o tsv)

# Test HTTP response
curl -I "https://$WEBAPP_URL"
# Expected: HTTP 200 OK (may take a few minutes after deployment)

# Open in browser
open "https://$WEBAPP_URL"  # macOS
xdg-open "https://$WEBAPP_URL"  # Linux
start "https://$WEBAPP_URL"  # Windows
```

#### Check Application Logs

```bash
# Stream logs
az webapp log tail --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3

# Download logs
az webapp log download --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --log-file webapp-logs.zip
```

#### Test Shopping Cart Functionality

Manual testing:
1. Open the web app URL
2. Verify product catalog loads
3. Add product to cart
4. View cart
5. Update quantity
6. Remove item
7. Complete checkout
8. Verify success message

Expected: All operations complete without errors.

### 4. Monitor Application Insights

```bash
# Query Application Insights for requests
az monitor app-insights query \
  --app $APPINSIGHTS_NAME \
  --resource-group rg-zavastore-dev-westus3 \
  --analytics-query "requests | take 10" \
  --offset 1h
```

Or use Azure Portal:
1. Navigate to Application Insights resource
2. Check "Live Metrics" for real-time data
3. View "Application Map" for dependencies
4. Check "Failures" for any errors

## Performance Testing

### Load Test (Basic)

```bash
# Install Apache Bench (if not available)
# Ubuntu: apt-get install apache2-utils
# macOS: Included by default

# Run basic load test (100 requests, 10 concurrent)
ab -n 100 -c 10 "https://$WEBAPP_URL/"
```

Monitor:
- Application Insights for performance metrics
- Web App metrics in Azure Portal
- Error rates

## Security Testing

### 1. Verify Security Settings

```bash
# Check TLS version
az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query siteConfig.minTlsVersion
# Expected: "1.2"

# Check FTPS state
az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query siteConfig.ftpsState
# Expected: "Disabled"
```

### 2. Test Container Image Pull

```bash
# Verify Web App can pull from ACR without credentials
az webapp log tail --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 | grep -i "pull"
# Should see successful image pulls without authentication errors
```

## Cost Validation

### Check Current Costs

```bash
# View cost analysis
az consumption usage list \
  --start-date $(date -d "7 days ago" +%Y-%m-%d) \
  --end-date $(date +%Y-%m-%d) \
  --query "[?contains(instanceName, 'zavastore')]"
```

Or use Azure Portal:
1. Navigate to Subscription > Cost Management
2. Filter by resource group: rg-zavastore-dev-westus3
3. Review daily costs

Expected: ~$1-2/day for dev environment

## Cleanup Testing

### Test Resource Deletion

```bash
# Delete resource group
az group delete --name rg-zavastore-dev-westus3 --yes --no-wait

# Verify deletion (may take several minutes)
az group show --name rg-zavastore-dev-westus3
# Expected: ResourceGroupNotFound error
```

## Common Issues and Solutions

### Issue: Deployment Timeout

**Symptom**: Deployment takes longer than 30 minutes
**Solution**: Check Azure Portal for detailed deployment status

```bash
# Check deployment status
az deployment group show \
  --resource-group rg-zavastore-dev-westus3 \
  --name <deployment-name> \
  --query properties.provisioningState
```

### Issue: Web App Not Starting

**Symptom**: HTTP 500 or 503 errors
**Solution**: Check logs and container configuration

```bash
# View container logs
az webapp log tail --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3

# Check container settings
az webapp config container show \
  --name $WEBAPP_NAME \
  --resource-group rg-zavastore-dev-westus3
```

### Issue: ACR Pull Failures

**Symptom**: "Failed to pull image" in logs
**Solution**: Verify managed identity and role assignment

```bash
# Check role assignments
PRINCIPAL_ID=$(az webapp show --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3 \
  --query identity.principalId -o tsv)

az role assignment list --assignee $PRINCIPAL_ID --all
```

### Issue: AI Foundry Quota Exceeded

**Symptom**: "QuotaExceeded" error during deployment
**Solution**: Request quota increase or use different region

```bash
# Check ML quota
az ml workspace show --name <hub-name> --resource-group rg-zavastore-dev-westus3
```

## Test Checklist

- [ ] Bicep templates validate without errors
- [ ] What-if analysis shows expected resources
- [ ] Deployment completes successfully
- [ ] All resources created (11 total minimum)
- [ ] Container Registry has no admin user
- [ ] Web App has managed identity
- [ ] AcrPull role assigned correctly
- [ ] Application Insights connected
- [ ] Web App accessible via HTTPS
- [ ] Shopping cart functionality works
- [ ] Application logs visible
- [ ] AI Foundry Hub and Project created
- [ ] Security settings correct (HTTPS, TLS 1.2)
- [ ] Estimated costs within budget
- [ ] Resource cleanup works

## Reporting Issues

When reporting deployment issues, include:

1. Deployment command used
2. Error messages (full text)
3. Deployment logs
4. Resource Group name
5. Azure region
6. Subscription type
7. Screenshots (if applicable)

Get deployment logs:
```bash
az deployment group show \
  --resource-group rg-zavastore-dev-westus3 \
  --name <deployment-name> \
  --query properties.error
```

## Continuous Testing

For ongoing validation:

1. **Set up Azure Monitor Alerts**: Alert on deployment failures, high costs, or security issues
2. **Schedule Validation Script**: Run `validate.sh` daily via cron or Azure DevOps
3. **Monitor Application Insights**: Check for errors and performance degradation
4. **Review Cost Reports**: Weekly cost reviews to ensure budget compliance

## Next Steps After Successful Testing

1. Configure custom domain
2. Set up SSL certificate
3. Configure autoscaling
4. Set up backup policies
5. Implement blue-green deployment
6. Configure staging slots
7. Set up model deployments in AI Foundry
8. Integrate with existing CI/CD pipelines
