# Deployment Readiness Checklist

This document outlines what you need to have ready before deploying the ZavaStorefront infrastructure to Azure.

## Required Information

Before you can deploy this infrastructure, you'll need:

### 1. Azure Subscription Details

- **Subscription ID**: Your Azure subscription identifier
  ```bash
  # Find your subscription ID
  az account list --output table
  ```

- **Subscription Type**: Pay-as-you-go, Enterprise, or other
- **Available Credits**: Estimated $25-40/month for dev environment

### 2. Azure Permissions

You need one of the following:
- **Owner** role on the subscription
- **Contributor** role on the subscription
- **Contributor** role on a resource group

Verify your permissions:
```bash
az role assignment list --assignee <your-email> --output table
```

### 3. Regional Quotas

Verify quotas in **westus3** region for:

#### App Service
```bash
az vm list-usage --location westus3 --query "[?name.value=='cores'].{Name:name.value, Current:currentValue, Limit:limit}" -o table
```

Required:
- **1 vCPU** minimum for B1 App Service Plan

#### Machine Learning (AI Foundry)
```bash
az ml workspace list-usage --location westus3 --output table
```

Required:
- **1 Machine Learning workspace** (Hub)
- **1 Machine Learning workspace** (Project)

If quotas are insufficient, request increases via Azure Portal:
- Navigate to: Subscriptions → Usage + quotas
- Select region: westus3
- Request quota increase

### 4. GitHub Repository Access (for CI/CD)

If using GitHub Actions, you'll need:

- **Repository admin access**: To configure secrets
- **Azure service principal**: For authentication

Create service principal:
```bash
az ad sp create-for-rbac \
  --name "zavastorefront-github" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/rg-zavastore-dev-westus3 \
  --sdk-auth
```

Save the output JSON securely - you'll need these values:
- `clientId` → GitHub secret: `AZURE_CLIENT_ID`
- `clientSecret` → (if using client secret auth)
- `subscriptionId` → GitHub secret: `AZURE_SUBSCRIPTION_ID`
- `tenantId` → GitHub secret: `AZURE_TENANT_ID`

## Pre-Deployment Preparation

### 1. Install Required Tools

#### Azure CLI
```bash
# Check if installed
az --version

# Install if needed
# Windows: https://aka.ms/installazurecliwindows
# macOS: brew update && brew install azure-cli
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Required version: 2.40.0 or later

#### Azure Developer CLI (Optional)
```bash
# Check if installed
azd version

# Install if needed
# Windows: winget install microsoft.azd
# macOS: brew tap azure/azd && brew install azd
# Linux: curl -fsSL https://aka.ms/install-azd.sh | bash
```

#### Docker (Optional - only for local testing)
Only needed if you want to test locally before deploying to Azure.
Azure ACR build can build images without local Docker.

### 2. Authenticate to Azure

```bash
# Login to Azure
az login

# Set the subscription
az account set --subscription <subscription-id>

# Verify authentication
az account show
```

### 3. Verify Bicep Installation

```bash
# Check Bicep version
az bicep version

# Update if needed
az bicep upgrade
```

Required version: 0.10.0 or later

### 4. Clone Repository

```bash
git clone https://github.com/<your-org>/TechWorkshop-L300-GitHub-Copilot-and-platform.git
cd TechWorkshop-L300-GitHub-Copilot-and-platform
```

## Deployment Options

You have three deployment options:

### Option A: Automated Script (Recommended for Quick Start)

**Requirements:**
- Azure CLI authenticated
- Bash shell (Linux/macOS/WSL/Git Bash)

**Command:**
```bash
./deploy.sh
```

**What it does:**
1. Creates resource group
2. Deploys all infrastructure
3. Builds Docker image in ACR
4. Configures Web App
5. Restarts Web App

**Time:** ~15-20 minutes

### Option B: Manual Step-by-Step (Recommended for Learning)

**Requirements:**
- Azure CLI authenticated

**Steps:** Follow [DEPLOYMENT.md](DEPLOYMENT.md) Option 2

**Time:** ~20-30 minutes

### Option C: Azure Developer CLI (azd)

**Requirements:**
- Azure Developer CLI installed and authenticated
- azd environment configured

**Commands:**
```bash
azd init
azd provision
azd deploy
```

**Time:** ~15-20 minutes

## What to Expect During Deployment

### Resource Creation Order

1. **Resource Group** (~30 seconds)
2. **Log Analytics Workspace** (~1-2 minutes)
3. **Application Insights** (~1 minute)
4. **Container Registry** (~2-3 minutes)
5. **Storage Account** (~1 minute)
6. **Key Vault** (~1 minute)
7. **App Service Plan** (~1-2 minutes)
8. **Web App** (~2-3 minutes)
9. **AI Foundry Hub** (~3-5 minutes)
10. **AI Foundry Project** (~2-3 minutes)
11. **Role Assignments** (~30 seconds)

**Total infrastructure deployment:** ~10-15 minutes

### Image Build and Deployment

After infrastructure:
1. **Docker image build in ACR** (~5-7 minutes)
2. **Web App configuration** (~1 minute)
3. **Web App restart** (~2-3 minutes)
4. **Application startup** (~1-2 minutes)

**Total additional time:** ~8-12 minutes

**Overall end-to-end time:** ~20-30 minutes

## Post-Deployment Actions

### 1. Retrieve Deployment Outputs

```bash
# Get all outputs
az deployment group show \
  --resource-group rg-zavastore-dev-westus3 \
  --name <deployment-name> \
  --query properties.outputs

# Get specific values
WEB_APP_URL=$(az deployment group show \
  --resource-group rg-zavastore-dev-westus3 \
  --name <deployment-name> \
  --query properties.outputs.webAppUrl.value -o tsv)

echo "Application URL: $WEB_APP_URL"
```

### 2. Test the Application

```bash
# Check HTTP status
curl -I "$WEB_APP_URL"

# Open in browser
open "$WEB_APP_URL"  # macOS
```

### 3. Validate All Resources

```bash
./validate.sh
```

### 4. Monitor Initial Metrics

View in Azure Portal:
- Application Insights → Live Metrics
- Web App → Monitoring → Metrics
- Cost Management → Cost Analysis

## Troubleshooting Deployment Issues

### Common Issues

#### Issue: "Insufficient Quota"
**Solution:** Request quota increase for the resource type in westus3

#### Issue: "Resource Provider Not Registered"
**Solution:**
```bash
az provider register --namespace Microsoft.Web
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.MachineLearningServices
```

#### Issue: "Location Not Available"
**Solution:** Some SKUs may not be available in westus3. Try:
- Different region (update `infra/main.bicepparam`)
- Different SKU (update module parameters)

#### Issue: "Deployment Timeout"
**Solution:** Re-run the deployment - it will pick up where it left off

#### Issue: "AI Foundry Deployment Failed"
**Reason:** AI Foundry resources require preview features or special quotas
**Solution:** 
1. Check Azure Portal for detailed error
2. Verify region supports AI Foundry
3. Request quota if needed
4. Consider removing AI Foundry modules if not needed immediately

### Get Help

1. **View detailed error:**
   ```bash
   az deployment group show \
     --resource-group rg-zavastore-dev-westus3 \
     --name <deployment-name> \
     --query properties.error
   ```

2. **Check activity logs:**
   ```bash
   az monitor activity-log list \
     --resource-group rg-zavastore-dev-westus3 \
     --max-events 20
   ```

3. **Azure Portal:**
   - Navigate to Resource Group
   - Click "Deployments" in left menu
   - Select failed deployment
   - View detailed error message

## Optional: GitHub Actions Setup

If you want automated deployments from GitHub:

### 1. Configure Federated Identity (Recommended)

```bash
# Create app registration
az ad app create --display-name zavastorefront-github

# Create federated credential
az ad app federated-credential create \
  --id <app-id> \
  --parameters '{
    "name": "github-actions",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<org>/<repo>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create service principal
az ad sp create --id <app-id>

# Assign role
az role assignment create \
  --assignee <app-id> \
  --role Contributor \
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-zavastore-dev-westus3
```

### 2. Add GitHub Secrets

In GitHub repository settings → Secrets and variables → Actions:

Add secrets:
- `AZURE_CLIENT_ID`: Application (client) ID
- `AZURE_TENANT_ID`: Directory (tenant) ID
- `AZURE_SUBSCRIPTION_ID`: Subscription ID

### 3. Run Workflow

- Go to Actions tab
- Select "Build and Deploy ZavaStorefront"
- Click "Run workflow"

## Cost Management

### Set Up Budget Alert

```bash
az consumption budget create \
  --budget-name zavastorefront-dev-monthly \
  --resource-group rg-zavastore-dev-westus3 \
  --amount 50 \
  --time-grain Monthly \
  --start-date $(date +%Y-%m-01) \
  --end-date 2025-12-31
```

This creates a budget of $50/month with alerts at 80%, 90%, and 100%.

### Monitor Costs Daily

```bash
# View current month costs
az consumption usage list \
  --start-date $(date +%Y-%m-01) \
  --end-date $(date +%Y-%m-%d) \
  | jq -r '.[] | select(.instanceName | contains("zavastore")) | .pretaxCost' \
  | awk '{sum+=$1} END {print "Total: $"sum}'
```

## Cleanup After Testing

If you're just testing and want to clean up:

```bash
# Delete everything
az group delete --name rg-zavastore-dev-westus3 --yes --no-wait
```

This removes:
- All Azure resources
- All costs (stops billing immediately)
- Cannot be undone

## Ready to Deploy?

✅ Checklist:
- [ ] Azure subscription ID obtained
- [ ] Sufficient permissions verified
- [ ] Regional quotas checked
- [ ] Azure CLI installed and authenticated
- [ ] Repository cloned
- [ ] Deployment option selected
- [ ] Budget alert configured (optional)
- [ ] GitHub Actions configured (optional)

If all boxes are checked, you're ready to deploy!

Choose your deployment method:
- **Quick start:** `./deploy.sh`
- **Step-by-step:** Follow [DEPLOYMENT.md](DEPLOYMENT.md)
- **Using azd:** `azd provision && azd deploy`

## Need Help?

- **Deployment guide:** [DEPLOYMENT.md](DEPLOYMENT.md)
- **Infrastructure details:** [infra/README.md](infra/README.md)
- **Testing guide:** [TESTING.md](TESTING.md)
- **Application docs:** [src/README.md](src/README.md)

## What You Need to Tell Me

To help with deployment, please provide:

1. **Your preferred deployment method:**
   - Automated script
   - Manual steps
   - Azure Developer CLI

2. **Deployment status information:**
   - Did the resource group create successfully?
   - Which resources deployed successfully?
   - Any error messages encountered?
   - Deployment name (if using manual deployment)

3. **Optional customizations:**
   - Different region than westus3?
   - Different resource group name?
   - Different SKUs for cost optimization?
   - Skip AI Foundry if not needed?

I can provide specific guidance based on your needs!
