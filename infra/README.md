# Infrastructure Documentation

This directory contains the Infrastructure as Code (IaC) for the ZavaStorefront application using Azure Bicep.

## Directory Structure

```
infra/
├── main.bicep              # Main orchestration template
├── main.bicepparam         # Parameters file for main template
└── modules/
    ├── container-registry.bicep    # Azure Container Registry
    ├── app-service-plan.bicep      # App Service Plan
    ├── web-app.bicep               # Web App (App Service)
    ├── app-insights.bicep          # Application Insights
    ├── log-analytics.bicep         # Log Analytics Workspace
    ├── storage-account.bicep       # Storage Account
    ├── key-vault.bicep             # Key Vault
    ├── ai-foundry-hub.bicep        # AI Foundry Hub
    ├── ai-foundry-project.bicep    # AI Foundry Project
    └── role-assignment.bicep       # RBAC role assignments
```

## Modules

### container-registry.bicep
Creates an Azure Container Registry (ACR) for storing Docker images.

**Parameters:**
- `name`: Registry name (must be globally unique)
- `location`: Azure region
- `sku`: SKU tier (Basic/Standard/Premium)
- `tags`: Resource tags

**Key Features:**
- Admin user disabled (uses managed identity)
- Public network access enabled
- Azure Services bypass for network rules

### app-service-plan.bicep
Creates a Linux App Service Plan for hosting the Web App.

**Parameters:**
- `name`: Plan name
- `location`: Azure region
- `sku`: SKU configuration (default: B1)
- `tags`: Resource tags

**Key Features:**
- Linux-based (required for containers)
- Basic tier for dev environment cost efficiency

### web-app.bicep
Creates a Linux Web App configured for Docker containers.

**Parameters:**
- `name`: Web App name (must be globally unique)
- `location`: Azure region
- `appServicePlanId`: App Service Plan resource ID
- `containerRegistryLoginServer`: ACR login server URL
- `dockerImageAndTag`: Docker image to deploy
- `appInsightsConnectionString`: Application Insights connection string
- `appInsightsInstrumentationKey`: Application Insights key
- `tags`: Resource tags

**Key Features:**
- System-assigned managed identity
- HTTPS only
- TLS 1.2 minimum
- Application Insights integration
- Configured to pull from ACR without passwords

### app-insights.bicep
Creates an Application Insights instance for monitoring.

**Parameters:**
- `name`: Application Insights name
- `location`: Azure region
- `workspaceId`: Log Analytics Workspace ID
- `tags`: Resource tags

**Key Features:**
- Workspace-based Application Insights
- Public network access for ingestion and query

### log-analytics.bicep
Creates a Log Analytics Workspace for Application Insights backend.

**Parameters:**
- `name`: Workspace name
- `location`: Azure region
- `sku`: Pricing tier (default: PerGB2018)
- `tags`: Resource tags

**Key Features:**
- 30-day retention
- PerGB2018 pricing model

### storage-account.bicep
Creates a Storage Account for AI Foundry Hub.

**Parameters:**
- `name`: Storage account name (must be globally unique, lowercase, no hyphens)
- `location`: Azure region
- `sku`: Storage SKU (default: Standard_LRS)
- `tags`: Resource tags

**Key Features:**
- StorageV2 (general purpose v2)
- Hot access tier
- TLS 1.2 minimum
- Public blob access disabled
- Encryption enabled

### key-vault.bicep
Creates a Key Vault for AI Foundry Hub secrets.

**Parameters:**
- `name`: Key Vault name (must be globally unique)
- `location`: Azure region
- `tenantId`: Azure AD tenant ID
- `tags`: Resource tags

**Key Features:**
- RBAC authorization enabled
- Soft delete enabled (7-day retention)
- Standard SKU
- Public network access with Azure Services bypass

### ai-foundry-hub.bicep
Creates an AI Foundry Hub (Machine Learning Workspace of kind 'Hub').

**Parameters:**
- `name`: Hub name
- `location`: Azure region
- `friendlyName`: Display name
- `description`: Hub description
- `storageAccountId`: Storage Account resource ID
- `keyVaultId`: Key Vault resource ID
- `appInsightsId`: Application Insights resource ID
- `containerRegistryId`: Container Registry resource ID
- `tags`: Resource tags

**Key Features:**
- Basic SKU for dev environment
- System-assigned managed identity
- Public network access enabled
- Linked to storage, Key Vault, Application Insights, and ACR

### ai-foundry-project.bicep
Creates an AI Foundry Project (Machine Learning Workspace of kind 'Project').

**Parameters:**
- `name`: Project name
- `location`: Azure region
- `friendlyName`: Display name
- `description`: Project description
- `hubId`: AI Foundry Hub resource ID
- `tags`: Resource tags

**Key Features:**
- Basic SKU for dev environment
- System-assigned managed identity
- Linked to Hub
- Public network access enabled

### role-assignment.bicep
Assigns the AcrPull role to the Web App's managed identity.

**Parameters:**
- `principalId`: Managed identity principal ID
- `containerRegistryId`: ACR resource ID

**Key Features:**
- Assigns built-in AcrPull role (7f951dda-4ed3-4680-a7ca-43fe172d538d)
- Scoped to resource group
- Enables passwordless ACR access

## Main Template (main.bicep)

The main template orchestrates all modules and creates the complete infrastructure.

### Parameters

- `environmentName`: Environment (dev/test/prod) - default: 'dev'
- `location`: Azure region - default: 'westus3'
- `baseName`: Base name for resources - default: 'zavastore'
- `dockerImageAndTag`: Docker image to deploy - default: 'zavastorefront:latest'

### Resource Naming Convention

Resources are named using this pattern:
- Resource Group: `rg-{baseName}-{env}-{location}`
- ACR: `acr{baseName}{env}{uniqueString}`
- App Service Plan: `asp-{baseName}-{env}-{location}`
- Web App: `app-{baseName}-{env}-{uniqueString}`
- Log Analytics: `log-{baseName}-{env}-{location}`
- App Insights: `appi-{baseName}-{env}-{location}`
- Storage Account: `st{baseName}{env}{uniqueString}`
- Key Vault: `kv-{baseName}-{env}-{uniqueString}`
- AI Hub: `aih-{baseName}-{env}-{location}`
- AI Project: `aip-{baseName}-{env}-{location}`

The `uniqueString()` function ensures globally unique names based on resource group ID.

### Outputs

- `resourceGroupName`: Name of the resource group
- `containerRegistryName`: ACR name
- `containerRegistryLoginServer`: ACR login server URL
- `webAppName`: Web App name
- `webAppUrl`: Web App URL
- `appInsightsName`: Application Insights name
- `appInsightsInstrumentationKey`: Application Insights instrumentation key
- `appInsightsConnectionString`: Application Insights connection string
- `aiFoundryHubName`: AI Foundry Hub name
- `aiFoundryProjectName`: AI Foundry Project name
- `storageAccountName`: Storage Account name
- `keyVaultName`: Key Vault name

## Deployment

See [DEPLOYMENT.md](../DEPLOYMENT.md) for detailed deployment instructions.

### Quick Start

```bash
# Create resource group
az group create --name rg-zavastore-dev-westus3 --location westus3

# Deploy infrastructure
az deployment group create \
  --resource-group rg-zavastore-dev-westus3 \
  --template-file main.bicep \
  --parameters main.bicepparam

# Get outputs
az deployment group show \
  --resource-group rg-zavastore-dev-westus3 \
  --name main \
  --query properties.outputs
```

## Customization

### Changing Environment

Edit `main.bicepparam`:

```bicep
param environmentName = 'test'  // or 'prod'
```

### Changing Region

Edit `main.bicepparam`:

```bicep
param location = 'eastus'  // or any supported region
```

**Note**: For AI Foundry, ensure the region supports GPT-4o-mini and Phi-4 models. As of deployment, westus3 is confirmed to support these models.

### Changing SKUs

Edit resource modules or override in `main.bicep`:

```bicep
// App Service Plan - upgrade to Standard
module appServicePlan 'modules/app-service-plan.bicep' = {
  params: {
    sku: {
      name: 'S1'
      tier: 'Standard'
      size: 'S1'
      family: 'S'
      capacity: 1
    }
  }
}

// ACR - upgrade to Standard for geo-replication
module containerRegistry 'modules/container-registry.bicep' = {
  params: {
    sku: 'Standard'
  }
}
```

## Security Considerations

1. **No Passwords**: ACR uses managed identity, not admin credentials
2. **HTTPS Only**: Web App enforces HTTPS
3. **TLS 1.2+**: Minimum TLS version enforced
4. **RBAC**: Role-based access control for ACR
5. **Managed Identities**: System-assigned identities for all services
6. **Key Vault**: Secrets stored in Key Vault
7. **Private Endpoints**: Can be added for enhanced security (not in Basic SKU)

## Monitoring

Application Insights collects:
- Application logs
- Performance metrics
- Request telemetry
- Dependency tracking
- Custom events

Access via Azure Portal or:

```bash
az monitor app-insights metrics show \
  --app <app-insights-name> \
  --resource-group rg-zavastore-dev-westus3 \
  --metric requests/count
```

## Cost Optimization

Current configuration uses minimal-cost SKUs:
- ACR: Basic (~$5/month)
- App Service: B1 (~$13/month)
- Storage: Standard_LRS (~$1-2/month)
- Key Vault: Standard (~$0.03/month)

For production:
- Consider Standard/Premium App Service with autoscaling
- Use Premium ACR for geo-replication
- Enable zone redundancy for high availability

## Maintenance

### Updating Infrastructure

1. Modify Bicep files
2. Validate changes:
   ```bash
   az deployment group what-if \
     --resource-group rg-zavastore-dev-westus3 \
     --template-file main.bicep \
     --parameters main.bicepparam
   ```
3. Deploy updates:
   ```bash
   az deployment group create \
     --resource-group rg-zavastore-dev-westus3 \
     --template-file main.bicep \
     --parameters main.bicepparam
   ```

### Backup

Key resources to backup:
- Key Vault secrets (automatic with soft delete)
- Storage Account data (enable versioning/soft delete)
- Web App configuration (export ARM template)

## Troubleshooting

### Deployment Failures

View deployment logs:
```bash
az deployment group show \
  --resource-group rg-zavastore-dev-westus3 \
  --name main \
  --query properties.error
```

### Resource Conflicts

If resources already exist, either:
1. Delete existing resources
2. Change resource names in parameters
3. Use existing resources (modify Bicep)

### Quota Issues

Check quotas:
```bash
az vm list-usage --location westus3 --output table
```

Request quota increase via Azure Portal if needed.

## References

- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure App Service](https://learn.microsoft.com/azure/app-service/)
- [Azure Container Registry](https://learn.microsoft.com/azure/container-registry/)
- [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure Machine Learning (AI Foundry)](https://learn.microsoft.com/azure/machine-learning/)
