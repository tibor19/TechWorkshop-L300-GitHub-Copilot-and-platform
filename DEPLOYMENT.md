# Azure Infrastructure Deployment Guide

This guide provides step-by-step instructions for deploying the ZavaStorefront application infrastructure to Azure using Bicep and Azure Developer CLI (azd).

## Prerequisites

1. **Azure CLI**: Install from [https://docs.microsoft.com/cli/azure/install-azure-cli](https://docs.microsoft.com/cli/azure/install-azure-cli)
2. **Azure Developer CLI (azd)**: Install from [https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
3. **Azure Subscription**: Active subscription with permissions to create resources
4. **Bicep CLI**: Usually included with Azure CLI
5. **Docker** (optional): Only if building images locally

## Architecture Overview

The infrastructure consists of:

- **Resource Group**: `rg-zavastore-dev-westus3` (single resource group in westus3)
- **Azure Container Registry (ACR)**: For storing container images (Basic SKU)
- **App Service Plan**: Linux-based B1 SKU for cost efficiency
- **Web App**: Linux Web App for Containers with system-assigned managed identity
- **Application Insights**: For monitoring and telemetry
- **Log Analytics Workspace**: Backend for Application Insights
- **Storage Account**: For AI Foundry Hub (Standard_LRS)
- **Key Vault**: For AI Foundry Hub secrets
- **AI Foundry Hub**: For AI/ML capabilities with GPT-4o-mini and Phi-4 access
- **AI Foundry Project**: Development project under the hub

## Deployment Steps

### Option 1: Using Azure Developer CLI (azd) - Recommended

1. **Login to Azure**
   ```bash
   azd auth login
   ```

2. **Initialize the environment**
   ```bash
   azd init
   ```

3. **Provision infrastructure**
   ```bash
   azd provision
   ```
   
   This will:
   - Create the resource group in westus3
   - Deploy all Bicep modules
   - Set up managed identity and role assignments
   - Configure Application Insights

4. **Build and push the Docker image**
   ```bash
   # Get ACR name from deployment outputs
   ACR_NAME=$(az acr list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)
   
   # Build and push using ACR build (no local Docker required)
   az acr build --registry $ACR_NAME --image zavastorefront:latest --file Dockerfile ./src
   ```

5. **Deploy the application**
   ```bash
   azd deploy
   ```

### Option 2: Using Azure CLI and Bicep Directly

1. **Login to Azure**
   ```bash
   az login
   ```

2. **Set the subscription**
   ```bash
   az account set --subscription <your-subscription-id>
   ```

3. **Create resource group**
   ```bash
   az group create --name rg-zavastore-dev-westus3 --location westus3
   ```

4. **Deploy infrastructure**
   ```bash
   az deployment group create \
     --resource-group rg-zavastore-dev-westus3 \
     --template-file infra/main.bicep \
     --parameters infra/main.bicepparam
   ```

5. **Get deployment outputs**
   ```bash
   az deployment group show \
     --resource-group rg-zavastore-dev-westus3 \
     --name main \
     --query properties.outputs
   ```

6. **Build and push Docker image**
   ```bash
   ACR_NAME=$(az deployment group show \
     --resource-group rg-zavastore-dev-westus3 \
     --name main \
     --query properties.outputs.containerRegistryName.value -o tsv)
   
   az acr build --registry $ACR_NAME --image zavastorefront:latest --file Dockerfile ./src
   ```

7. **Update Web App to use the image**
   ```bash
   WEBAPP_NAME=$(az deployment group show \
     --resource-group rg-zavastore-dev-westus3 \
     --name main \
     --query properties.outputs.webAppName.value -o tsv)
   
   ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
   
   az webapp config container set \
     --name $WEBAPP_NAME \
     --resource-group rg-zavastore-dev-westus3 \
     --docker-custom-image-name ${ACR_LOGIN_SERVER}/zavastorefront:latest
   
   az webapp restart --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3
   ```

### Option 3: Using GitHub Actions (CI/CD)

1. **Set up Azure credentials**
   
   Create a service principal:
   ```bash
   az ad sp create-for-rbac --name "zavastorefront-github" \
     --role contributor \
     --scopes /subscriptions/<subscription-id>/resourceGroups/rg-zavastore-dev-westus3 \
     --sdk-auth
   ```

2. **Configure GitHub Secrets**
   
   Add these secrets to your GitHub repository:
   - `AZURE_CLIENT_ID`: Service principal client ID
   - `AZURE_TENANT_ID`: Azure tenant ID
   - `AZURE_SUBSCRIPTION_ID`: Azure subscription ID

3. **Deploy infrastructure manually first**
   ```bash
   az deployment group create \
     --resource-group rg-zavastore-dev-westus3 \
     --template-file infra/main.bicep \
     --parameters infra/main.bicepparam
   ```

4. **Trigger the workflow**
   
   The workflow (`.github/workflows/deploy.yml`) will automatically:
   - Build the Docker image using ACR build (no local Docker)
   - Push to ACR
   - Deploy to Web App
   
   Trigger it by:
   - Pushing to main branch
   - Running manually from GitHub Actions UI

## Verification Steps

1. **Check resource group**
   ```bash
   az group show --name rg-zavastore-dev-westus3
   ```

2. **List all resources**
   ```bash
   az resource list --resource-group rg-zavastore-dev-westus3 --output table
   ```

3. **Verify Web App**
   ```bash
   WEBAPP_URL=$(az webapp show \
     --name <webapp-name> \
     --resource-group rg-zavastore-dev-westus3 \
     --query defaultHostName -o tsv)
   
   echo "Web App URL: https://$WEBAPP_URL"
   curl -I https://$WEBAPP_URL
   ```

4. **Check managed identity role assignment**
   ```bash
   WEBAPP_PRINCIPAL_ID=$(az webapp show \
     --name <webapp-name> \
     --resource-group rg-zavastore-dev-westus3 \
     --query identity.principalId -o tsv)
   
   az role assignment list --assignee $WEBAPP_PRINCIPAL_ID --output table
   ```

5. **View Application Insights**
   ```bash
   az monitor app-insights component show \
     --app <appinsights-name> \
     --resource-group rg-zavastore-dev-westus3
   ```

6. **Check AI Foundry Hub and Project**
   ```bash
   az ml workspace list --resource-group rg-zavastore-dev-westus3 --output table
   ```

## Troubleshooting

### Issue: ACR pull fails
**Solution**: Verify the managed identity has AcrPull role:
```bash
ACR_ID=$(az acr show --name <acr-name> --resource-group rg-zavastore-dev-westus3 --query id -o tsv)
az role assignment list --scope $ACR_ID --output table
```

### Issue: Web App not starting
**Solution**: Check logs:
```bash
az webapp log tail --name <webapp-name> --resource-group rg-zavastore-dev-westus3
```

### Issue: Application Insights not receiving data
**Solution**: Verify connection string is set:
```bash
az webapp config appsettings list \
  --name <webapp-name> \
  --resource-group rg-zavastore-dev-westus3 \
  --query "[?name=='APPLICATIONINSIGHTS_CONNECTION_STRING']"
```

### Issue: AI Foundry deployment fails
**Solution**: Check region quota:
```bash
az ml workspace show \
  --name <hub-name> \
  --resource-group rg-zavastore-dev-westus3
```

## Cost Estimation

Monthly costs (approximate, dev environment):

- **Container Registry (Basic)**: ~$5/month
- **App Service Plan (B1)**: ~$13/month
- **Application Insights**: ~$2-5/month (based on usage)
- **Log Analytics**: ~$2-5/month (based on ingestion)
- **Storage Account (Standard_LRS)**: ~$1-2/month
- **Key Vault**: ~$0.03/month (Standard tier)
- **AI Foundry Hub & Project (Basic)**: ~$0-10/month (based on usage)

**Total estimated**: ~$25-40/month for dev environment

## Cleanup

To delete all resources:

```bash
az group delete --name rg-zavastore-dev-westus3 --yes --no-wait
```

Or using azd:

```bash
azd down
```

## Security Best Practices

1. ✅ **No admin credentials**: ACR admin user is disabled
2. ✅ **Managed identity**: Web App uses system-assigned managed identity
3. ✅ **RBAC**: Role-based access control for ACR pulls
4. ✅ **HTTPS only**: Web App enforces HTTPS
5. ✅ **TLS 1.2**: Minimum TLS version enforced
6. ✅ **Secrets in Key Vault**: AI Foundry uses Key Vault for secrets
7. ✅ **No public storage**: Storage account blob public access disabled

## Next Steps

1. Configure custom domain and SSL certificate
2. Set up monitoring alerts in Application Insights
3. Configure AI models in AI Foundry Project
4. Implement backup and disaster recovery
5. Set up staging slots for blue-green deployments
6. Configure autoscaling rules

## Support

For issues or questions:
- Check Azure Portal for resource status
- Review Application Insights for application errors
- Check GitHub Actions logs for deployment issues
- Review Azure Activity Log for infrastructure issues
