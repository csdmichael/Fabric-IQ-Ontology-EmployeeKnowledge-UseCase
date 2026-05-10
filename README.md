# Microsoft Fabric IQ � Employee Knowledge Graph Demo

Complete solution for building an employee knowledge graph using Microsoft Fabric, Azure services, and Power BI.

---

## ?? Quick Start

### Clone & Deploy (2-3 hours)

```bash
git clone https://github.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase.git
cd Fabric-IQ-Ontology-EmployeeKnowledge-UseCase

# Deploy API and infrastructure
.\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUB_ID"

# Verify deployment
.\scripts\verify-deployment.ps1
```

### What Gets Deployed
- ? FastAPI Python server on Azure App Service
- ? Configuration and data files (1,020 records)
- ? Fabric ontology and pipeline definitions
- ? Manual: Load data to OneLake, create Power BI reports

**See [QUICK_START.md](QUICK_START.md) for detailed quick reference**

---

## ?? Documentation

| Document | Purpose |
|----------|---------|
| [QUICK_START.md](QUICK_START.md) | 5-minute overview and key commands |
| [FABRIC_DEPLOYMENT_GUIDE.md](FABRIC_DEPLOYMENT_GUIDE.md) | Step-by-step Fabric setup (20 min) |
| [powerbi/POWERBI_SETUP_GUIDE.md](powerbi/POWERBI_SETUP_GUIDE.md) | Power BI configuration guide |
| [powerbi/FABRIC_POWERBI_DEPLOYMENT_PLAYBOOK.md](powerbi/FABRIC_POWERBI_DEPLOYMENT_PLAYBOOK.md) | Comprehensive 70-minute deployment playbook |
| [api/README.md](api/README.md) | API endpoints and usage |

---

## ??? Architecture

### Data Flow
```
JSON Data Files
    ?
Python Script (populate_fabric_complete.py)
    ?
CSV Exports (OneLake upload)
    ?
Fabric Semantic Model
    ?
Power BI Reports & Dashboards
```

### Core Components
- **API**: FastAPI server at `https://fabric-iq-emp-knowledge-api.azurewebsites.net`
- **Data**: 1,020 records (100 employees, 100 contributions, 800 digital assets, 20 projects)
- **Fabric**: Ontology with 4 tables, 2 relationships, 5 measures
- **Pipeline**: 4-stage process (Extract, Transform, Load, Validate)
- **Power BI**: 3 reports with 11 visuals

---

## ?? Repository Structure

```
+-- api/
�   +-- server.py              # FastAPI application
�   +-- README.md              # API documentation
+-- config/
�   +-- endpoints.json         # Fabric IDs and Azure endpoints
�   +-- fabric-settings.json   # Fabric configuration
�   +-- ...                    # Other configs
+-- data/
�   +-- employees.json         # 100 employee records
�   +-- contributions.json     # 100 contributions
�   +-- digital_assets.json    # 800 assets
�   +-- projects.json          # 20 projects
�   +-- exports/parquet/       # CSV exports for OneLake
+-- fabric/
�   +-- ontology/              # Table schema and relationships
�   +-- pipelines/             # Data pipeline definitions
�   +-- powerbi/               # Power BI configurations
+-- scripts/
�   +-- deploy-complete-solution.ps1  # Main deployment
�   +-- populate_fabric_complete.py   # Data preparation
�   +-- verify-deployment.ps1         # Health checks
+-- terraform/
�   +-- main.tf                # Azure resources
�   +-- ...                    # Terraform files
+-- README.md                  # This file
```

---

## ? Deployment Scripts

### Deploy (Primary)
```powershell
.\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUB_ID"
```
- Verifies prerequisites (Python, Azure CLI, Git)
- Deploys API to Azure App Service
- Validates all configurations
- Outputs deployment status

### Verify
```powershell
.\scripts\verify-deployment.ps1
```
- Tests API health check
- Validates Azure resources
- Confirms all files present
- Checks Fabric configuration

### Data Preparation
```bash
python scripts/populate_fabric_complete.py
```
- Loads and validates 1,020 records
- Creates ontology with relationships
- Defines Power BI measures
- Exports CSV files for OneLake

---

## ?? Configuration

All configurations are stored in `config/` directory. Key files:

| File | Purpose |
|------|---------|
| `endpoints.json` | Fabric workspace/lakehouse IDs, Azure URLs |
| `fabric-settings.json` | Fabric workspace configuration |
| `ontology-config.json` | Table schemas and relationships |
| `azure-hosting-resources.json` | Azure resource details |

---

## ?? Data Model

### Tables
- **Employees** (100 records): ID, name, department, role, skills, tier, email
- **Contributions** (100 records): Employee ID, type, score, date
- **DigitalAssets** (800 records): Owner, type, name, created date
- **Projects** (20 records): Name, status, lead, team, timeline

### Relationships
- `Contributions[employeeId] ? Employees[employeeId]`
- `DigitalAssets[employeeId] ? Employees[employeeId]`

### Power BI Measures
- Total Employees
- Total Contributions
- Average Contribution Score
- Total Digital Assets
- Total Projects

---

## ?? Power BI Reports

### 3 Reports (11 Visuals Total)
1. **Employee Skills Dashboard** (4 visuals)
   - Employee count by tier
   - Skills distribution
   - Contribution heatmap
   - Top contributors

2. **Project Contribution Analysis** (3 visuals)
   - Projects by status
   - Team member allocation
   - Contribution timeline

3. **Digital Assets Distribution** (4 visuals)
   - Assets by type
   - Assets by owner
   - Creation trends
   - Asset metadata

---

## ?? Deployment Stages

### Stage 1: API Deployment (Automated)
- Git archive repository code
- Deploy to Azure App Service
- Configure startup command
- Verify health checks
- **Time**: ~10 minutes

### Stage 2: Data Preparation (Automated)
- Load JSON source files
- Validate data integrity (1,020 records)
- Create ontology with 4 tables
- Define 2 relationships and 5 measures
- Export CSV files
- **Time**: ~5 minutes

### Stage 3: OneLake Data Load (Manual)
- Upload CSV files to OneLake
- Configure table mappings
- Validate record counts
- **Time**: ~10 minutes

### Stage 4: Power BI Configuration (Manual)
- Create semantic model relationships
- Add 5 Power BI measures
- Create 3 reports with 11 visuals
- Build main dashboard
- **Time**: ~30 minutes

### Stage 5: Publishing (Manual)
- Publish Power BI app
- Grant team access
- Configure refresh schedule
- **Time**: ~5 minutes

---

## ?? Azure Resources

### Created by Deployment Script
- **App Service Plan**: B3 (Linux)
- **Web Apps**: 
  - `fabric-iq-emp-knowledge-api` (API)
  - `fabric-iq-emp-knowledge-ui` (Frontend)
- **Storage Account**: `aistoragemyaacoub` (blob storage)
- **Cosmos DB**: `cosmos-ai-poc` (document storage)
- **AI Search**: `aisearch-poc-myaacoub` (semantic search)
- **Document Intelligence**: Document parsing service

### Fabric Resources
- **Workspace**: Employee Knowledge Graph
- **Lakehouse**: Data lake for OneLake
- **Semantic Model**: Power BI semantic model
- **Pipeline**: 4-stage data pipeline

---

## ?? API Endpoints

### Health Check
```
GET /health
```
Returns 200 OK if API is running.

### Swagger Documentation
```
GET /docs
```
Interactive API documentation.

### API Base URL
```
https://fabric-iq-emp-knowledge-api.azurewebsites.net
```

See [api/README.md](api/README.md) for full endpoint documentation.

---

## ?? Technologies

- **Backend**: Python 3.7+, FastAPI
- **Infrastructure**: Azure App Service, Storage, Cosmos DB, AI Search
- **Analytics**: Microsoft Fabric, Power BI
- **IaC**: Terraform
- **Deployment**: PowerShell, Azure CLI, Git

---

## ?? Next Steps

1. **Clone repository** and run deployment script
2. **Run verification** to confirm all systems working
3. **Follow [FABRIC_DEPLOYMENT_GUIDE.md](FABRIC_DEPLOYMENT_GUIDE.md)** to load data to OneLake
4. **Follow [powerbi/FABRIC_POWERBI_DEPLOYMENT_PLAYBOOK.md](powerbi/FABRIC_POWERBI_DEPLOYMENT_PLAYBOOK.md)** for:
   - Configure semantic model relationships
   - Build Power BI reports
   - Create dashboards
   - Publish Power BI app

---

## ? Verification

After deployment, verify everything is working:

```powershell
# Check API health
curl https://fabric-iq-emp-knowledge-api.azurewebsites.net/health

# View API documentation
# Open in browser: https://fabric-iq-emp-knowledge-api.azurewebsites.net/docs

# Run full verification
.\scripts\verify-deployment.ps1
```

Expected results:
- ? API returns 200 OK
- ? Swagger documentation available
- ? All configuration files present
- ? Data files validated (1,020 records)
- ? Azure resources accessible
- ? Fabric IDs configured

---

## ?? Rebuilding from GitHub

To rebuild the entire solution in a new environment:

1. **Clone the repository**
   ```bash
   git clone https://github.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase.git
   ```

2. **Run deployment script**
   ```powershell
   .\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUBSCRIPTION_ID"
   ```

3. **Verify deployment**
   ```powershell
   .\scripts\verify-deployment.ps1
   ```

4. **Complete manual steps** (see deployment guides)

**Total rebuild time**: 2-3 hours (mostly manual Power BI configuration)

---

## ?? Support

- **Quick Reference**: [QUICK_START.md](QUICK_START.md)
- **Fabric Setup**: [FABRIC_DEPLOYMENT_GUIDE.md](FABRIC_DEPLOYMENT_GUIDE.md)
- **Power BI Deployment**: [powerbi/FABRIC_POWERBI_DEPLOYMENT_PLAYBOOK.md](powerbi/FABRIC_POWERBI_DEPLOYMENT_PLAYBOOK.md)
- **Power BI Guide**: [powerbi/POWERBI_SETUP_GUIDE.md](powerbi/POWERBI_SETUP_GUIDE.md)
- **Power BI Summary**: [powerbi/FABRIC_POWERBI_DEPLOYMENT_SUMMARY.md](powerbi/FABRIC_POWERBI_DEPLOYMENT_SUMMARY.md)
- **API Details**: [api/README.md](api/README.md)
- **GitHub**: https://github.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase

---

## ?? License

See [LICENSE](LICENSE) file for details.

---

**Status**: Production Ready ?  
**Last Updated**: May 10, 2026  
**API Health**: https://fabric-iq-emp-knowledge-api.azurewebsites.net/health
