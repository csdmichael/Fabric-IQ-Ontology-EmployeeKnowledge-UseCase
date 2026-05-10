# Fabric IQ - Solution Rebuild Guide

**This guide explains how to rebuild the entire Fabric IQ solution from scratch using GitHub source code.**

## Overview

The Fabric IQ solution is **fully reproducible** from the GitHub repository. All source code, configuration files, deployment scripts, and automation tools are included.

**Rebuild Time**: ~2 hours (mostly manual Power BI configuration)
**Cost**: Uses existing Azure resources (configure your own if first-time)

---

## Prerequisites

### Software Requirements
- **Git** - To clone the repository
- **Azure CLI (az)** - To manage Azure resources
- **Python 3.7+** - For automation scripts
- **PowerShell 7+** (Windows) - For deployment scripts

### Azure Requirements
- Active Azure subscription
- Resource group created (`ai-myaacoub` or your custom name)
- Azure CLI authenticated: `az login`

### Fabric & Power BI
- Microsoft Fabric workspace access
- Power BI Pro or Premium license
- Access to Power BI Admin Portal

### GitHub
- Clone access to the repository

---

## Step-by-Step Rebuild Process

### Step 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase.git
cd Fabric-IQ-Ontology-EmployeeKnowledge-UseCase

# Verify you have all source code
ls -la api config data fabric scripts terraform
```

**Expected Files**:
- `api/server.py` - FastAPI Python server
- `config/*.json` - Configuration files (endpoints, Fabric IDs, etc.)
- `data/*.json` - Source data (employees, contributions, assets, projects)
- `fabric/` - Ontology, pipelines, Power BI configs
- `scripts/` - Python automation scripts
- `terraform/` - Infrastructure as Code

---

### Step 2: Configure Azure Environment

#### Option A: Use Existing Azure Resources (Recommended for Testing)

If you already have an Azure resource group set up:

```bash
# Set your subscription
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify resource group exists
az group show --name ai-myaacoub
```

Update configuration files with your Azure details:

**File**: `config/endpoints.json`
```json
{
  "azure": {
    "blobStorageEndpoint": "https://YOUR_STORAGE_ACCOUNT.blob.core.windows.net",
    "documentIntelligenceEndpoint": "https://YOUR_DOC_INTELLIGENCE.cognitiveservices.azure.com/"
  },
  "hosting": {
    "apiUrl": "https://YOUR_API_DOMAIN.azurewebsites.net",
    "uiPublicUrl": "https://YOUR_UI_DOMAIN.azurewebsites.net"
  }
}
```

#### Option B: Provision New Resources with Terraform

```bash
cd terraform

# Configure variables
# Edit: terraform.tfvars with your values
cat > terraform.tfvars << 'EOF'
resource_group_name = "ai-myaacoub"
location = "eastus"
app_service_plan_name = "plan-fabriciq-b3"
app_service_plan_sku = "B3"
storage_account_name = "aistoragemyaacoub"
EOF

# Initialize and apply Terraform
terraform init
terraform plan
terraform apply

# Save output values
terraform output -json > ../config/azure-hosting-resources.json

cd ..
```

---

### Step 3: Deploy API

Choose your deployment method:

#### Method A: Automated Deployment (Recommended)

**PowerShell** (Windows):
```powershell
.\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUB_ID" -ResourceGroup "ai-myaacoub"
```

**Python** (Cross-platform):
```bash
python scripts/deploy_complete_solution.py
```

#### Method B: Manual Deployment

```bash
# Create deployment package
$zip = Join-Path $env:TEMP "fabriciq-api-deploy.zip"
git archive --format=zip --output $zip HEAD api config data fabric README.md LICENSE

# Deploy to Azure
az webapp deploy \
  --name fabric-iq-emp-knowledge-api \
  --resource-group ai-myaacoub \
  --src-path $zip \
  --type zip

# Configure startup
az webapp config set \
  --name fabric-iq-emp-knowledge-api \
  --resource-group ai-myaacoub \
  --startup-file "python -u api/server.py"

# Restart
az webapp restart \
  --name fabric-iq-emp-knowledge-api \
  --resource-group ai-myaacoub

# Verify (wait 45 seconds after restart)
curl https://fabric-iq-emp-knowledge-api.azurewebsites.net/health
```

**Expected Output**: `200 OK`

---

### Step 4: Prepare Fabric Workspace

#### Update Fabric Configuration

**File**: `config/endpoints.json`
```json
{
  "microsoftFabric": {
    "workspaceId": "YOUR_WORKSPACE_ID",
    "lakehouseId": "YOUR_LAKEHOUSE_ID",
    "semanticModelId": "YOUR_SEMANTIC_MODEL_ID",
    "pipelineId": "YOUR_PIPELINE_ID"
  }
}
```

**How to find IDs**:
1. Go to https://app.powerbi.com
2. Navigate to your Fabric workspace
3. Open Lakehouse → URL contains IDs
4. Open semantic model → URL contains ID

#### Create Lakehouse (if not exists)

1. In Power BI workspace: **New** → **Lakehouse**
2. Name: `employee_knowledge_lakehouse`
3. Create
4. Copy the lakehouse ID to `config/endpoints.json`

#### Create Semantic Model (if not exists)

1. In Power BI: **New** → **Semantic Model**
2. Upload data from `data/employees.json`, etc. (temporary)
3. Copy semantic model ID to config
4. Delete the temporary data (we'll load from OneLake)

---

### Step 5: Load Data to OneLake

#### Option A: Quick Manual Upload (5 minutes)

1. Go to Power BI workspace
2. Open Lakehouse
3. Click **Get data** → **Upload files**
4. Upload these files from `data/exports/parquet/`:
   - `Employees.csv`
   - `Contributions.csv`
   - `DigitalAssets.csv`
   - `Projects.csv`
5. Create tables with default names

#### Option B: Power Query (Recommended, 10 minutes)

1. Open Power BI Desktop or Online editor
2. **Get data** → **Web (blank query)**
3. Open Advanced Editor and paste:
   ```m
   let
     Employees = Json.Document(Web.Contents("https://raw.githubusercontent.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/main/data/employees.json")),
     Contributions = Json.Document(Web.Contents("https://raw.githubusercontent.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/main/data/contributions.json")),
     DigitalAssets = Json.Document(Web.Contents("https://raw.githubusercontent.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/main/data/digital_assets.json")),
     Projects = Json.Document(Web.Contents("https://raw.githubusercontent.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/main/data/projects.json"))
   in
     [Employees = Employees, Contributions = Contributions, DigitalAssets = DigitalAssets, Projects = Projects]
   ```
4. **Load and transform**
5. Publish to Fabric workspace

#### Verify Data Load

```bash
# Check files exist
ls -la data/exports/parquet/

# Count records
python -c "
import pandas as pd
employees = pd.read_csv('data/exports/parquet/Employees.csv')
contributions = pd.read_csv('data/exports/parquet/Contributions.csv')
assets = pd.read_csv('data/exports/parquet/DigitalAssets.csv')
projects = pd.read_csv('data/exports/parquet/Projects.csv')
print(f'Employees: {len(employees)}')
print(f'Contributions: {len(contributions)}')
print(f'Assets: {len(assets)}')
print(f'Projects: {len(projects)}')
print(f'Total: {len(employees) + len(contributions) + len(assets) + len(projects)}')
"
```

**Expected**: 1,020 total records

---

### Step 6: Configure Semantic Model

1. Go to semantic model in Power BI
2. **Model** tab (or gear icon)
3. **Add relationships**:
   - `Contributions[employeeId]` → `Employees[employeeId]`
   - `DigitalAssets[employeeId]` → `Employees[employeeId]`

4. **Add measures** (click on table, then "+"):
   - `Total Employees` = `COUNTA(Employees[employeeId])`
   - `Total Contributions` = `SUM(Contributions[contributionScore])`
   - `Avg Score` = `AVERAGE(Contributions[contributionScore])`
   - `Total Assets` = `COUNTA(DigitalAssets[assetId])`
   - `Total Projects` = `COUNTA(Projects[projectId])`

5. **Publish**

---

### Step 7: Create Power BI Reports

Reference configurations in: `fabric/powerbi/powerbi_reports_config.json`

#### Report 1: Employee Skills Dashboard

1. New report in workspace
2. Add visuals:
   - **KPI Card**: Total Employees measure
   - **Table**: Columns: name, department, role, skills, score
   - **Bar Chart**: Axis: department, Value: count of employees
   - **Pie Chart**: Legend: tier, Values: count of employees
3. Save as `Employee Skills Dashboard`

#### Report 2: Project Contribution Analysis

1. New report
2. Add visuals:
   - **KPI Card**: Total Projects
   - **Table**: Project name, status, lead, members
   - **Scatter**: X: projects, Y: contribution score
   - **Bar**: Top 10 employees by contribution score
3. Save as `Project Contribution Analysis`

#### Report 3: Digital Assets Distribution

1. New report
2. Add visuals:
   - **KPI Card**: Total Assets
   - **Pie**: Asset type distribution
   - **Bar**: Assets by employee
   - **Table**: Asset ID, name, type, owner, created date
3. Save as `Digital Assets Distribution`

---

### Step 8: Create Dashboards

1. **New dashboard**: Name `Employee Knowledge Dashboard`
2. **Pin visuals** from the 3 reports:
   - Employee count KPI
   - Contributions by department
   - Project status overview
   - Asset distribution
3. **Arrange** for presentation
4. **Save**

---

### Step 9: Publish Power BI App

1. Go to **Apps** (left sidebar)
2. **Create app**
3. Fill in:
   - Name: `Employee Knowledge App`
   - Description: `Enterprise employee knowledge and insights platform`
   - Icon/logo (optional)
4. **Navigation**:
   - Add all 3 reports
   - Add main dashboard
   - Organize into sections
5. **Permissions**: Select audience
6. **Publish**

---

### Step 10: Set Up Data Refresh

1. Semantic model → **Settings** (gear icon)
2. **Scheduled refresh**:
   - Set frequency (daily recommended)
   - Set time (off-peak hours)
3. **Save**

---

## Verification Checklist

Complete rebuild verification:

```bash
# Source code
[ ] Git repository cloned
[ ] api/server.py exists
[ ] config/*.json present
[ ] data/exports/parquet/*.csv present (1,020 records)
[ ] fabric/ontology/fabric_iq_ontology_complete.json exists
[ ] fabric/pipelines/employee_knowledge_pipeline_complete.json exists
[ ] fabric/powerbi/powerbi_reports_config.json exists
[ ] scripts/*.py present

# Azure
[ ] API endpoint health check returns 200 OK
[ ] Swagger documentation loads
[ ] App Service plan running

# Fabric/Power BI
[ ] Workspace created and accessible
[ ] Lakehouse created with 4 tables (1,020 records)
[ ] Semantic model has 2 relationships
[ ] Semantic model has 5 measures
[ ] 3 reports created with 11 visuals
[ ] 1 main dashboard created
[ ] Power BI app published

# Functionality
[ ] API responds to health checks
[ ] Power BI app accessible to users
[ ] Dashboards display data
[ ] Refresh schedules configured
```

---

## Troubleshooting

### API Health Check Fails
```bash
# View deployment logs
az webapp log download \
  --name fabric-iq-emp-knowledge-api \
  --resource-group ai-myaacoub \
  --log-file logs.zip

# Check startup file
az webapp config show \
  --name fabric-iq-emp-knowledge-api \
  --resource-group ai-myaacoub \
  --query startupCommand
```

### Data Not Appearing in OneLake
1. Verify CSV files uploaded
2. Check table names match configuration
3. Refresh semantic model (wait 2-3 minutes)
4. Re-load query in Power Query

### Reports Show No Data
1. Verify OneLake tables populated
2. Check relationships created correctly
3. Verify measure expressions are valid
4. Refresh Power BI (Ctrl+R)

### Power BI App Won't Publish
1. Ensure all reports are published first
2. Check workspace permissions
3. Verify no unresolved query errors
4. Try publishing report again

---

## Time Estimates

| Task | Time | Automated? |
|------|------|-----------|
| Clone repository | 2 min | ✓ |
| Configure Azure | 5 min | ✗ |
| Deploy API | 10 min | ✓ |
| Create Lakehouse | 2 min | ✗ |
| Load data to OneLake | 10 min | ✗ |
| Configure semantic model | 10 min | ✗ |
| Create Power BI reports | 30 min | ✗ |
| Create dashboards | 15 min | ✗ |
| Publish Power BI app | 5 min | ✗ |
| **Total** | **~90 min** | **~40% automated** |

---

## Deployment Scripts Reference

### Python Script (Cross-Platform)
```bash
python scripts/deploy_complete_solution.py
```

### PowerShell Script (Windows)
```powershell
.\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUB_ID"
```

Both scripts:
- Verify prerequisites
- Validate configurations
- Deploy API
- Prepare data
- Verify Fabric setup
- Generate documentation

---

## What's Included in Repository

```
Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/
├── api/
│   └── server.py                          # FastAPI server
├── config/
│   ├── endpoints.json                     # API & Fabric endpoints
│   ├── fabric-settings.json               # Fabric configuration
│   ├── ontology-config.json               # Ontology settings
│   └── terraform.tfvars.json              # Terraform variables
├── data/
│   ├── employees.json                     # 100 employee records
│   ├── contributions.json                 # 100 contribution records
│   ├── digital_assets.json                # 800 asset records
│   ├── projects.json                      # 20 project records
│   └── exports/parquet/                   # CSV exports for OneLake
│       ├── Employees.csv
│       ├── Contributions.csv
│       ├── DigitalAssets.csv
│       └── Projects.csv
├── fabric/
│   ├── ontology/
│   │   └── fabric_iq_ontology_complete.json
│   ├── pipelines/
│   │   └── employee_knowledge_pipeline_complete.json
│   └── powerbi/
│       ├── powerbi_reports_config.json
│       ├── PowerQuery_OneLake_Loader.m
│       └── employee_knowledge_dashboards.json
├── scripts/
│   ├── populate_fabric_complete.py        # Data preparation
│   ├── create_dashboards_automated.py     # Dashboard automation
│   ├── deploy_complete_solution.py        # Python deployment script
│   └── deploy-complete-solution.ps1       # PowerShell deployment script
├── terraform/
│   ├── main.tf                            # Infrastructure definition
│   ├── variables.tf                       # Terraform variables
│   ├── outputs.tf                         # Output values
│   └── versions.tf                        # Provider versions
├── docs/                                  # Additional documentation
├── QUICK_START.md                         # 5-minute overview
├── DEPLOYMENT_STATUS.md                   # Infrastructure details
├── FABRIC_DEPLOYMENT_GUIDE.md             # Step-by-step guide
├── POWERBI_SETUP_GUIDE.md                 # Power BI setup
├── COMPLETION_SUMMARY.md                  # Current status
└── REBUILD_GUIDE.md                       # This file
```

---

## Support & Resources

- **Documentation**: See all `.md` files in repository root
- **GitHub Issues**: Report problems in GitHub issues
- **Configuration Reference**: See `config/endpoints.json`
- **Architecture Diagram**: See `DEPLOYMENT_STATUS.md`

---

## Next Steps After Rebuild

1. **Add users** to Power BI workspace
2. **Configure row-level security** (optional)
3. **Set up email subscriptions** to dashboards
4. **Implement automated alerts** for anomalies
5. **Create additional reports** as needed

---

**Version**: 1.0
**Last Updated**: May 10, 2026
**Status**: Complete and reproducible from GitHub
