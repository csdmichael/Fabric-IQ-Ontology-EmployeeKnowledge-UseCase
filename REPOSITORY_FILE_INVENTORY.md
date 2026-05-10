# Repository File Inventory

**Complete reference of all files in the Fabric IQ solution repository and their purposes.**

---

## Directory Structure Overview

```
Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/
├── api/                                    # Python API server
├── config/                                 # Configuration files
├── data/                                   # Source data and exports
├── docs/                                   # Documentation assets
├── fabric/                                 # Fabric artifacts
├── scripts/                                # Automation and deployment scripts
├── terraform/                              # Infrastructure as Code
├── ui/                                     # Frontend (Ionic/Angular)
├── LICENSE                                 # License file
├── README.md                               # Main documentation
├── QUICK_START.md                          # 5-minute guide
├── DEPLOYMENT_STATUS.md                    # Infrastructure details
├── FABRIC_DEPLOYMENT_GUIDE.md              # Fabric deployment steps
├── POWERBI_SETUP_GUIDE.md                  # Power BI configuration
├── COMPLETION_SUMMARY.md                   # Project status
├── REBUILD_GUIDE.md                        # How to rebuild from GitHub
└── .gitignore, .github/                    # Git configuration
```

---

## Root Level Files

| File | Purpose | Status |
|------|---------|--------|
| `README.md` | Main project documentation | Active |
| `QUICK_START.md` | 5-minute executive overview | Active |
| `DEPLOYMENT_STATUS.md` | Current infrastructure and deployment status | Active |
| `FABRIC_DEPLOYMENT_GUIDE.md` | Step-by-step Fabric and Power BI deployment | Active |
| `POWERBI_SETUP_GUIDE.md` | Power BI setup options (manual and automated) | Active |
| `COMPLETION_SUMMARY.md` | Project completion status and next steps | Active |
| `REBUILD_GUIDE.md` | How to rebuild entire solution from GitHub | Active |
| `LICENSE` | Apache 2.0 license | Static |

---

## api/ Directory

**Purpose**: Python FastAPI server that serves employee knowledge endpoints

| File | Purpose | Status |
|------|---------|--------|
| `api/server.py` | Main FastAPI application server | Deployed |
| | - Health check endpoint: `/health` | |
| | - Swagger docs: `/docs`, `/swagger.json` | |
| | - Employee endpoints: `/api/employees/*` | |
| | - Port: 8080 (internal), HTTPS on Azure | |
| | - Detects HTTPS from forwarded headers | |

**Deployment**:
- Runs on Azure App Service (B3 plan)
- Startup file: `python -u api/server.py`
- URL: `https://fabric-iq-emp-knowledge-api.azurewebsites.net`

**Configuration**: Uses `config/endpoints.json` and `config/fabric-settings.json`

---

## config/ Directory

**Purpose**: Centralized configuration for all services

| File | Purpose | Contents |
|------|---------|----------|
| `endpoints.json` | API and service endpoints | Microsoft Fabric IDs, Azure blob storage, Document Intelligence endpoints, API URLs |
| `fabric-settings.json` | Fabric workspace settings | Workspace ID, lakehouse ID, semantic model ID, pipeline ID |
| `ontology-config.json` | Ontology settings | Schema configuration for Fabric tables |
| `azure-hosting-resources.json` | Azure resource IDs | App Service plans, storage accounts, Cosmos DB, AI Search |
| `terraform.tfvars.json` | Terraform variables | Resource names, SKUs, regions, tags |
| `workflows.json` | Workflow configurations | Orchestration and automation workflows |

**Key IDs** (from deployed solution):
```json
{
  "workspace_id": "38362838-0531-4215-89af-a8a79221b545",
  "lakehouse_id": "d11b209f-c774-481e-adcb-79920a94fd20",
  "semantic_model_id": "21e0a7be-1e7d-4110-8faa-d835f81c6559",
  "pipeline_id": "944b78ab-c7da-465b-9559-c3461be2e11e"
}
```

---

## data/ Directory

**Purpose**: Source data, exports, and employee documents

### JSON Source Files
| File | Records | Purpose |
|------|---------|---------|
| `employees.json` | 100 | Employee master data (ID, name, department, role, skills, tier, email) |
| `contributions.json` | 100 | Contribution metrics (employee ID, contribution type, score, date) |
| `digital_assets.json` | 800 | Digital assets catalog (ID, owner, type, name, created, modified) |
| `projects.json` | 20 | Project information (ID, name, status, lead, team, start, end) |

**Total**: 1,020 records ready for Fabric

### data/exports/parquet/ Directory

**Purpose**: CSV exports ready for OneLake upload

| File | Rows | Columns | Purpose |
|------|------|---------|---------|
| `Employees.csv` | 100 | 8 | Employee master data for OneLake |
| `Contributions.csv` | 100 | 5 | Contribution metrics for OneLake |
| `DigitalAssets.csv` | 800 | 6 | Digital assets for OneLake |
| `Projects.csv` | 20 | 7 | Project information for OneLake |

**Upload To**: Fabric workspace → Lakehouse tables

### data/employees/ Directory

**Purpose**: Individual employee document folders

| Item | Contents | Purpose |
|------|----------|---------|
| `EMP001/` through `EMP100/` | Text and OneNote files | Simulated employee documents (resumes, notes, assets) |
| Example: `AST-EMP001-04.txt` | Text file | Sample employee document |
| Example: `AST-EMP001-05.one` | OneNote file | Sample employee note |

**Used By**: Document Intelligence for content extraction and ontology enrichment

---

## fabric/ Directory

**Purpose**: Microsoft Fabric artifacts and configurations

### fabric/ontology/

| File | Purpose | Generated | Status |
|------|---------|-----------|--------|
| `fabric_iq_ontology.json` | Original ontology template | Pre-configured | Reference |
| `fabric_iq_ontology_complete.json` | Complete ontology with all configs | Script-generated | Active |

**Contents**:
- Table schemas (Employees, Contributions, DigitalAssets, Projects)
- 2 relationships (Contributions→Employees, DigitalAssets→Employees)
- 5 Power BI measures (Total Employees, Contributions, Assets, Projects, Avg Score)
- Primary/foreign key definitions

### fabric/pipelines/

| File | Purpose | Generated | Status |
|------|---------|-----------|--------|
| `employee_knowledge_pipeline.json` | Original pipeline template | Pre-configured | Reference |
| `employee_knowledge_pipeline_complete.json` | Complete 4-stage pipeline | Script-generated | Active |

**Pipeline Stages**:
1. **Extract**: Load JSON from source files
2. **Transform**: Normalize and validate data
3. **Load**: Upsert to OneLake tables
4. **Validate**: Data quality checks

### fabric/powerbi/

| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| `employee_knowledge_dashboards.json` | Dashboard templates | 200+ | Reference |
| `powerbi_reports.json` | Report templates (original) | 150+ | Reference |
| `powerbi_reports_config.json` | Complete report config (11 visuals) | 300+ | Active |
| `PowerQuery_OneLake_Loader.m` | Power Query M script | 50+ | Active |

**Report Configurations**:
1. **Employee Skills Dashboard** (4 visuals)
   - Total Employees KPI
   - Employee details table
   - Contributions by Department bar chart
   - Employees by Tier pie chart

2. **Project Contribution Analysis** (3 visuals)
   - Total Projects KPI
   - Project details table
   - Top contributors bar chart

3. **Digital Assets Distribution** (4 visuals)
   - Total Assets KPI
   - Assets by Type pie chart
   - Assets by Employee bar chart
   - Asset catalog table

**Power Query Script**: Loads all 4 data sources directly from JSON files

### fabric/agents/

| File | Purpose | Status |
|------|---------|--------|
| `employee_knowledge_agent.json` | Employee knowledge query agent | Reference |
| `sre_agent.json` | SRE/operations agent | Reference |

**Note**: These are template configurations for Fabric Data Agents

### fabric/semantic-model/

| File | Purpose | Status |
|------|---------|--------|
| `employee_knowledge_semantic_model.json` | Semantic model template | Reference |

---

## scripts/ Directory

**Purpose**: Python and PowerShell automation scripts

### Python Scripts

| Script | Purpose | Executable | Status |
|--------|---------|-----------|--------|
| `populate_fabric_complete.py` | Load data and generate all configs | ✓ Yes | Executed |
| `create_dashboards_automated.py` | Create dashboards via Power BI API | ✓ Yes | Ready |
| `deploy_complete_solution.py` | End-to-end deployment orchestration | ✓ Yes | Ready |
| `generate_employee_files.py` | Generate synthetic employee documents | ✓ Yes | Utility |
| `generate_executive_diagrams.py` | Generate architecture diagrams | ✓ Yes | Utility |

### PowerShell Scripts

| Script | Purpose | Platform | Status |
|--------|---------|----------|--------|
| `deploy-complete-solution.ps1` | Windows deployment automation | PowerShell 7+ | Ready |

**Key Functions**:
- Phase 1: Verify prerequisites (Python, Azure CLI, Git)
- Phase 2: Prepare source code
- Phase 3: Validate configurations
- Phase 4: Deploy API to Azure
- Phase 5: Prepare data for OneLake
- Phase 6: Verify Fabric setup
- Phase 7: Generate documentation

### data/storage_map.json

| File | Purpose |
|------|---------|
| `scripts/storage_map.json` | Maps data sources to OneLake tables |

---

## terraform/ Directory

**Purpose**: Infrastructure as Code for Azure resources

| File | Purpose | Resources |
|------|---------|-----------|
| `main.tf` | Primary infrastructure definitions | App Service Plan (B3), Web Apps (API/UI), Storage Account, Cosmos DB |
| `variables.tf` | Variable definitions | Resource names, SKUs, regions, tags |
| `outputs.tf` | Output values | Resource IDs, URLs, connection strings |
| `versions.tf` | Provider versions | Azure provider, required versions |

**Resources Created**:
- App Service Plan: `plan-fabriciq-b3` (B3 SKU, Linux)
- Web Apps:
  - API: `fabric-iq-emp-knowledge-api`
  - UI: `fabric-iq-emp-knowledge-ui`
- Storage Account: `aistoragemyaacoub`
- Cosmos DB: `cosmos-ai-poc`
- AI Search: `aisearch-poc-myaacoub`
- Document Intelligence: `doc-intelligence-poc-my`

**Deploy**: `terraform init && terraform apply`

---

## ui/ Directory

**Purpose**: Frontend application (Ionic/Angular)

| Path | Purpose | Status |
|------|---------|--------|
| `ui/ionic-angular/` | Ionic + Angular application | Configured |
| `ui/ionic-angular/package.json` | NPM dependencies | Configured |
| `ui/ionic-angular/src/` | Application source code | Configured |

**Framework**: Ionic 7 + Angular + TypeScript

**Note**: UI deployment is optional (core functionality works via API)

---

## docs/ Directory

**Purpose**: Documentation assets and examples

| File | Purpose |
|------|---------|
| `DEMO_SCRIPT.md` | Demonstration walkthrough steps |
| `incident-response-plan.md` | SRE incident response procedures |
| `prompts.txt` | Sample Agent prompts (30+) |
| `ui-preview.html` | UI mockup preview |

---

## .github/ Directory

**Purpose**: GitHub Actions workflows and configuration

| File | Purpose | Status |
|------|---------|--------|
| `.github/workflows/` | CI/CD pipeline definitions | Configured |
| `.gitignore` | Git ignore rules | Standard |

---

## How Everything Connects

### Data Flow
```
Raw JSON Data
    ↓
populate_fabric_complete.py (extract, validate, transform)
    ↓
CSV Exports (data/exports/parquet/)
    ↓
Power Query or Manual Upload
    ↓
OneLake Tables (Employees, Contributions, Assets, Projects)
    ↓
Semantic Model (relationships + measures)
    ↓
Power BI Reports (11 visuals, 3 reports)
    ↓
Power BI Dashboards & App
```

### Configuration Flow
```
config/endpoints.json
    ↓
API Server (api/server.py)
API uses config for:
- Fabric workspace IDs
- Azure storage endpoints
- Document Intelligence endpoints
```

### Deployment Flow
```
GitHub Repository
    ↓
deploy-complete-solution.ps1 or deploy_complete_solution.py
    ↓
Azure App Service (API)
    ↓
Manual: Load data to OneLake
Manual: Create Power BI reports/dashboards
```

---

## File Size Reference

| Item | Size | Note |
|------|------|------|
| `data/employees.json` | ~30 KB | 100 records |
| `data/contributions.json` | ~25 KB | 100 records |
| `data/digital_assets.json` | ~200 KB | 800 records |
| `data/projects.json` | ~5 KB | 20 records |
| CSV exports (total) | ~250 KB | All 4 files combined |
| Fabric configs (total) | ~100 KB | Ontology, pipeline, Power BI |
| API server | ~50 KB | `api/server.py` |
| Deployment scripts | ~100 KB | Python + PowerShell |
| Documentation | ~250 KB | All markdown files |
| **Total Repository** | **~1.5 MB** | Without node_modules |

---

## What Gets Deployed

### Automatic (Deployment Scripts)
- ✓ API server to Azure App Service
- ✓ All configuration files
- ✓ Data files and exports
- ✓ Fabric configuration artifacts

### Manual (Following Guides)
- ✗ Data upload to OneLake (see FABRIC_DEPLOYMENT_GUIDE.md)
- ✗ Semantic model relationships (see FABRIC_DEPLOYMENT_GUIDE.md)
- ✗ Power BI reports (see POWERBI_SETUP_GUIDE.md)
- ✗ Dashboards (see POWERBI_SETUP_GUIDE.md)
- ✗ Power BI app publishing (see POWERBI_SETUP_GUIDE.md)

---

## How to Find Things

| Need | Location |
|------|----------|
| Quick overview | `QUICK_START.md` |
| Deploy from GitHub | `REBUILD_GUIDE.md` |
| Infrastructure details | `DEPLOYMENT_STATUS.md` |
| Power BI setup | `POWERBI_SETUP_GUIDE.md` |
| Fabric deployment | `FABRIC_DEPLOYMENT_GUIDE.md` |
| API documentation | `README.md` → API Service section |
| Data schemas | `fabric/ontology/fabric_iq_ontology_complete.json` |
| Source code | `api/server.py` |
| Deployment automation | `scripts/deploy_complete_solution.py` or `.ps1` |
| Terraform IaC | `terraform/*.tf` |
| Configuration | `config/*.json` |

---

## Maintenance & Updates

### To Update Data
1. Edit JSON files in `data/`
2. Run `scripts/populate_fabric_complete.py`
3. Re-upload CSV exports to OneLake

### To Update API
1. Edit `api/server.py`
2. Commit to Git
3. Run deployment script (auto-deploys)

### To Update Configuration
1. Edit `config/*.json`
2. Commit to Git
3. Run deployment script or manual Azure CLI commands

### To Update Power BI Reports
1. See `POWERBI_SETUP_GUIDE.md`
2. Edit reports in Power BI portal
3. Save and republish

---

## Environment Variables

The solution uses configuration files (no environment variables).

**To customize for your environment**:
1. Edit `config/endpoints.json`
2. Update with your Azure resource URLs
3. Update with your Fabric workspace/lakehouse IDs
4. Update with your Power BI details

---

## Backup & Recovery

**All source code is in GitHub** → Fully reproducible

**To recover**:
1. Clone from GitHub
2. Update configurations
3. Run deployment scripts
4. Recreate Power BI artifacts (manual)

**Estimated Recovery Time**: 2-3 hours

---

## License & Attribution

- License: Apache 2.0 (see LICENSE file)
- Created for demonstration purposes
- Uses synthetic data
- Can be extended and customized

---

**Repository Version**: 1.0
**Last Updated**: May 10, 2026
**Status**: Complete and deployable
