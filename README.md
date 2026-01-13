# ZavaStorefront Workshop - L300 GitHub Copilot and Azure Platform

This lab guides you through a series of practical exercises focused on modernising Zava's business applications and databases by migrating everything to Azure, leveraging GitHub Enterprise, Copilot, and Azure services. Each exercise is designed to deliver hands-on experience in governance, automation, security, AI integration, and observability, ensuring Zava's transition to Azure is robust, secure, and future-ready.

## Application

**ZavaStorefront** is a sample ASP.NET Core 6 MVC e-commerce application that demonstrates modern cloud-native development practices with Azure integration.

### Features
- Product catalog with 8 sample products
- Shopping cart with session-based storage
- Responsive design with Bootstrap 5
- Containerized deployment to Azure App Service
- Application monitoring with Azure Application Insights
- AI capabilities via Microsoft Foundry (AI Hub & Project)

## Azure Infrastructure

The application infrastructure is fully automated using **Bicep** and **Azure Developer CLI (azd)**:

### Resources Deployed
- **Azure Container Registry (ACR)** - Container image storage with managed identity authentication
- **App Service Plan** - Linux-based hosting (B1 SKU for dev)
- **Web App** - Container-based web application with system-assigned managed identity
- **Application Insights** - Application performance monitoring and telemetry
- **Log Analytics Workspace** - Backend for Application Insights
- **Storage Account** - For AI Foundry Hub
- **Key Vault** - Secure secrets management for AI Foundry
- **AI Foundry Hub** - Machine Learning workspace for AI/ML capabilities
- **AI Foundry Project** - Development project with GPT-4o-mini and Phi-4 access

All resources are deployed to a single resource group (`rg-zavastore-dev-westus3`) in the **westus3** region.

### Security Features
- ✅ No password-based authentication (managed identities only)
- ✅ HTTPS enforcement
- ✅ TLS 1.2 minimum
- ✅ Role-based access control (RBAC)
- ✅ Private blob storage
- ✅ Secure Key Vault integration

## Quick Start

### Prerequisites
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
- Active Azure subscription
- (Optional) [Docker Desktop](https://www.docker.com/products/docker-desktop) for local development

### Deploy to Azure

**Option 1: One-command deployment**
```bash
./deploy.sh
```

**Option 2: Step-by-step deployment**
```bash
# 1. Login to Azure
az login

# 2. Create resource group
az group create --name rg-zavastore-dev-westus3 --location westus3

# 3. Deploy infrastructure
az deployment group create \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam

# 4. Build and push Docker image (no local Docker required)
ACR_NAME=$(az acr list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)
az acr build --registry $ACR_NAME --image zavastorefront:latest --file Dockerfile ./src

# 5. Deploy to Web App
WEBAPP_NAME=$(az webapp list --resource-group rg-zavastore-dev-westus3 --query "[0].name" -o tsv)
az webapp restart --name $WEBAPP_NAME --resource-group rg-zavastore-dev-westus3
```

### Validate Deployment
```bash
./validate.sh
```

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Comprehensive deployment guide with multiple deployment options
- **[infra/README.md](infra/README.md)** - Infrastructure documentation and Bicep module details
- **[src/README.md](src/README.md)** - Application documentation and development guide

## CI/CD

GitHub Actions workflow is included for automated deployments:
- **Workflow**: `.github/workflows/deploy.yml`
- **Triggers**: Push to main branch or manual workflow dispatch
- **Actions**: Build Docker image in ACR, deploy to App Service
- **Authentication**: Uses Azure federated identity (OIDC)

### Setup GitHub Actions
1. Create service principal for GitHub Actions
2. Add secrets to GitHub repository:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
3. Push to main branch or manually trigger workflow

## Cost Estimation

Development environment (approximate monthly costs):
- Container Registry (Basic): ~$5
- App Service (B1): ~$13
- Application Insights: ~$2-5
- Log Analytics: ~$2-5
- Storage Account: ~$1-2
- Key Vault: ~$0.03
- AI Foundry: ~$0-10 (usage-based)

**Total**: ~$25-40/month

## Local Development

```bash
cd src
dotnet restore
dotnet run
```

Open browser to `https://localhost:5001`

## Cleanup

To delete all Azure resources:
```bash
az group delete --name rg-zavastore-dev-westus3 --yes --no-wait
```

Or:
```bash
azd down
```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
