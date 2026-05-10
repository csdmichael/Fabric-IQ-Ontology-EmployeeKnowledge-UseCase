# Microsoft Fabric IQ – Employee Knowledge Graph

A complete demo solution that builds an employee knowledge graph using **Microsoft Fabric**, **Azure** cloud services, **Power BI**, and a **FastAPI** backend — all provisioned and deployed through **Terraform** and **GitHub Actions**.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Data Flow](#data-flow)
3. [Ontology & Data Model](#ontology--data-model)
4. [UI Overview](#ui-overview)
5. [Technologies](#technologies)
6. [Repository Structure](#repository-structure)
7. [Quick Start](#quick-start)
8. [Configuration](#configuration)
9. [Deployment](#deployment)
10. [API Reference](#api-reference)
11. [Monitoring](#monitoring)
12. [License](#license)

---

## Architecture

The solution runs entirely on Azure, with Microsoft Fabric providing the data lakehouse and semantic layer, and Power BI delivering analytics reports.

![Architecture Diagram](docs/architecture-diagram.png)

| Layer | Components |
|---|---|
| **Data Ingestion** | Azure Blob Storage (raw → processed) → Fabric data pipeline |
| **Knowledge Layer** | Microsoft Fabric OneLake lakehouse + ontology + semantic model |
| **Analytics** | Power BI reports and dashboards |
| **API** | FastAPI (Python) on Azure App Service |
| **UI** | Ionic Angular on Azure App Service |
| **Observability** | Azure Monitor alerts + Log Analytics + Logic App for SRE |

---

## Data Flow

The diagram below shows how data moves from source JSON files through Azure services and into Power BI.

![Data Pipeline Diagram](docs/data-pipeline-diagram.png)

```
JSON source files  (data/*.json)
        │
        ▼
Azure Blob Storage  (employee-knowledge-raw container)
        │  [upload-employee-assets workflow]
        ▼
Fabric Data Pipeline  (4-stage: Extract → Transform → Load → Validate)
        │
        ▼
OneLake Lakehouse  (4 tables: Employees, Contributions, DigitalAssets, Projects)
        │
        ▼
Fabric Semantic Model  (2 relationships, 5 DAX measures)
        │
        ▼
Power BI Reports & Dashboards  (3 reports, 11 visuals)
        │
        ▼
FastAPI  (/api/* endpoints consumed by the Ionic Angular UI)
```

The `populate_fabric_complete.py` script pre-processes JSON files, generates the ontology and pipeline config, and exports CSV files that the Fabric pipeline ingests. Data upload to blob storage is automated by the `upload-employee-assets` GitHub Actions workflow.

---

## Ontology & Data Model

The knowledge graph models employees and their relationships to projects, digital assets, and contributions.

![Ontology Diagram](docs/ontology-diagram.png)

![Semantic Model ERD](docs/semantic-model-erd.png)

### Tables

| Table | Records | Primary Key | Description |
|---|---|---|---|
| **Employees** | 100 | `employeeId` | Name, department, role, skills, tier, email |
| **Contributions** | 100 | `employeeId` | Contribution score, project count, asset count, tier |
| **DigitalAssets** | 800 | `assetId` | Owner, type, title, last modified date |
| **Projects** | 20 | `projectId` | Name, status, lead, description |

### Relationships

```
Contributions[employeeId]  →  Employees[employeeId]   (many-to-one)
DigitalAssets[employeeId]  →  Employees[employeeId]   (many-to-one)
```

### Power BI DAX Measures

| Measure | Expression |
|---|---|
| Total Employees | `COUNTA(Employees[employeeId])` |
| Total Contributions | `SUM(Contributions[contributionScore])` |
| Average Employee Score | `AVERAGE(Contributions[contributionScore])` |
| Total Assets | `COUNTA(DigitalAssets[assetId])` |
| Total Projects | `COUNTA(Projects[projectId])` |

---

## UI Overview

The Ionic Angular frontend provides dashboards, employee directory, org chart, leaderboard, Power BI report links, and an AI agent chat interface.

![UI Screenshot](docs/ui-screenshot.png)

Navigation is organised into three sections: **Source Data** (employees, projects, data sources), **Reports & Dashboards** (Power BI reports, leaderboard, org chart), and **AI Agents** (employee agent, agent prompts).

---

## Technologies

| Technology | Role |
|---|---|
| **Microsoft Fabric** | Workspace, OneLake lakehouse, data pipeline, semantic model, ontology |
| **Power BI** | Analytical reports and dashboards built on the Fabric semantic model |
| **Azure App Service** | Hosts the FastAPI backend (`api`) and Ionic Angular frontend (`ui`) |
| **Azure Blob Storage** | Stores raw and processed employee asset files; Fabric pipeline ingestion source |
| **Azure Cosmos DB** | Stores parsed employee documents and SRE incident records |
| **Azure Monitor** | Metric alerts (storage availability, Cosmos errors, App Service 5xx / response time), Log Analytics workspace, and a Logic App for automated SRE incident response |
| **FastAPI (Python 3.12)** | REST API serving employee data, org hierarchy, Power BI report metadata, and agent configurations |
| **Ionic Angular** | Single-page web app providing the UI |
| **Terraform** | Infrastructure as Code for all Azure resources (storage, Cosmos DB, App Service plan, web apps, Log Analytics, Monitor alerts, Logic App) |
| **GitHub Actions** | CI validation (`ci.yml`), Terraform plan/apply + API/UI deployment (`deploy.yml`), employee asset upload (`upload-employee-assets.yml`), and integration smoke tests (`test-deployment.yml`) |
| **Python scripts** | Data preparation (`populate_fabric_complete.py`) and employee file generation |

---

## Repository Structure

```
.github/workflows/
  ci.yml                        # JSON validation, UI scaffold check, Terraform fmt/validate
  deploy.yml                    # Terraform plan/apply + API & UI deploy + Fabric REST API calls
  upload-employee-assets.yml    # Uploads data files to Azure Blob Storage
  test-deployment.yml           # Post-deploy integration smoke tests
  provision-sre-agent.yml       # Provisions the SRE agent definition

api/
  server.py                     # FastAPI application (all /api/* endpoints)
  README.md                     # API endpoint reference

config/
  endpoints.json                # Fabric workspace/lakehouse/model IDs and Azure URLs
  azure-hosting-resources.json  # Resource group, app names (read by deploy.yml)
  fabric-settings.json          # Fabric workspace settings
  ontology-config.json          # Local ontology entity/relationship reference
  terraform.tfvars.json         # Terraform variable values (edit before first deploy)
  workflows.json                # CI/CD version pins and path configuration

data/
  employees.json                # 100 employee records
  contributions.json            # 100 contribution records
  digital_assets.json           # 800 digital asset records
  projects.json                 # 20 project records
  org_hierarchy.json            # Org chart hierarchy
  emails.json                   # Sample email activity
  parsed_documents_cosmosdb.json# Parsed document metadata (served by API)
  storage_map.json              # Blob storage path config (read by upload workflow)
  exports/parquet/              # CSV exports for Fabric ingestion

docs/
  architecture-diagram.png      # Full solution architecture
  data-pipeline-diagram.png     # End-to-end data flow
  ontology-diagram.png          # Knowledge graph ontology
  semantic-model-erd.png        # Power BI semantic model ERD
  ui-screenshot.png             # UI preview

fabric/
  ontology/
    fabric_iq_ontology_complete.json    # Ontology with all tables, PKs, FKs
  pipelines/
    employee_knowledge_pipeline_complete.json  # 4-stage pipeline config
  dataflows/
    employee_ingestion_dataflow.json    # Dataflow definition
  powerbi/
    powerbi_reports.json               # Report definitions (read by API + deploy)
    powerbi_reports_config.json        # Visual/page configuration
    PowerQuery_OneLake_Loader.m        # Power Query M script for OneLake load
    employee_knowledge_dashboards.json # Dashboard pin configuration
  agents/
    employee_knowledge_agent.json      # Fabric data agent definition + sample prompts
    sre_agent.json                     # SRE Fabric agent definition
  semantic-model/
    employee_knowledge_semantic_model.json  # Semantic model schema

scripts/
  deploy.sh                     # Primary Terraform-based deploy (Linux/macOS)
  deploy-complete-solution.ps1  # Windows wrapper (calls Terraform + az CLI)
  populate_fabric_complete.py   # Data prep: loads JSON, generates configs, exports CSVs
  test-integration.ps1          # Integration smoke tests (API + agent + data checks)
  verify-deployment.ps1         # Local health check (API, Azure resources, data files)

terraform/
  versions.tf                   # Provider version constraints
  variables.tf                  # All input variable declarations
  main.tf                       # Storage, Cosmos DB, App Service plan, API/UI web apps
  monitors.tf                   # Log Analytics, Monitor alerts, Logic App
  outputs.tf                    # Exported resource URLs and IDs
  .terraform.lock.hcl           # Provider lock file

ui/
  ionic-angular/                # Ionic Angular web application
    src/app/pages/              # Page components (employees, org-chart, leaderboard, …)
    src/app/services/           # Config service
    server.js                   # Node.js static server
```

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase.git
cd Fabric-IQ-Ontology-EmployeeKnowledge-UseCase

# 2. Fill in your values (see Configuration section below)
#    - config/terraform.tfvars.json
#    - config/endpoints.json
#    - GitHub repository secrets

# 3. Push to main (triggers Terraform plan/apply + deploy)
git push origin main

# 4. (Optional) Trigger apply manually from GitHub Actions → Deploy → Run workflow → apply=true
```

After the workflow completes:
- API: `https://<api_app_service_name>.azurewebsites.net/health`
- UI: `https://<ui_app_service_name>.azurewebsites.net`
- Swagger: `https://<api_app_service_name>.azurewebsites.net/docs`

---

## Configuration

All configuration lives in `config/`. Edit these files before the first deployment — no portal steps required.

### Terraform Variables — `config/terraform.tfvars.json`

These values are passed directly to Terraform on every `plan`/`apply` run.

| Variable | Description | Example |
|---|---|---|
| `resource_group_name` | Existing Azure resource group | `"ai-myaacoub"` |
| `storage_account_name` | Globally unique storage account name | `"stfabriciqdemodata01"` |
| `cosmos_account_name` | Globally unique Cosmos DB account name | `"cosmos-fabriciq-demo-01"` |
| `cosmos_database_name` | Cosmos DB database name | `"EmployeeKnowledgeGraph"` |
| `cosmos_container_name` | Primary Cosmos container | `"EmployeeDocumentParsing"` |
| `ui_app_service_name` | Azure App Service name for the UI | `"fabric-iq-emp-knowledge-ui"` |
| `api_app_service_name` | Azure App Service name for the API | `"fabric-iq-emp-knowledge-api"` |
| `app_service_plan_sku` | App Service SKU | `"B3"` |
| `app_service_plan_location` | Region for App Service plan | `"westus2"` |
| `fabric_capacity_id` | Full ARM resource ID of the Fabric capacity | `"/subscriptions/.../capacities/..."` |
| `sre_alert_email` | Email for Azure Monitor alert notifications | `"sre@example.com"` |
| `sre_webhook_url` | Teams/Slack webhook for SRE alerts | `"https://..."` |
| `tags` | Tags applied to all resources | `{"project":"fabric-iq","env":"demo"}` |

### Fabric & Azure Endpoints — `config/endpoints.json`

Update after the Fabric workspace is provisioned (the `deploy-fabric-components` workflow step creates it automatically if it does not exist).

| Key path | Description |
|---|---|
| `microsoftFabric.workspaceId` | Fabric workspace GUID |
| `microsoftFabric.lakehouseId` | OneLake lakehouse GUID |
| `microsoftFabric.semanticModelId` | Power BI semantic model GUID |
| `microsoftFabric.capacityId` | Fabric capacity GUID (short form) |
| `microsoftFabric.pipelineId` | Data pipeline GUID |
| `microsoftFabric.dataAgentId` | Fabric data agent GUID |
| `hosting.apiUrl` | Deployed API URL |
| `hosting.uiPublicUrl` | Deployed UI URL |

### Azure Hosting Config — `config/azure-hosting-resources.json`

Read by the deploy workflow to know which resource group and App Service names to target.

| Key path | Description |
|---|---|
| `subscriptionId` | Azure subscription ID |
| `resourceGroup` | Resource group name |
| `hosting.apiWebApp.name` | API App Service name |
| `hosting.uiWebApp.name` | UI App Service name |

### GitHub Secrets

Set these in **Settings → Secrets and variables → Actions** of your repository fork.

| Secret | Required | Description |
|---|---|---|
| `AZURE_CLIENT_ID` | Yes (OIDC) | Service principal / managed identity client ID |
| `AZURE_TENANT_ID` | Yes (OIDC) | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Recommended | Overrides subscription from config file |
| `AZURE_CREDENTIALS` | Alt to OIDC | Full service principal JSON (fallback auth) |
| `AZURE_STORAGE_ACCOUNT` | Yes | Storage account name for data upload steps |

> **OIDC is recommended** — it requires no secret rotation. Create a federated credential on your service principal for the `repo:<owner>/<repo>:ref:refs/heads/main` subject.

---

## Deployment

All infrastructure and application deployment is handled by GitHub Actions. There are no manual portal steps.

### CI — `ci.yml`

Runs on every push to non-main branches and on pull requests. Validates:
- All JSON files in `config/`, `data/`, `fabric/` parse correctly
- Required UI scaffold files and `package.json` dependencies exist
- Terraform formatting (`terraform fmt -check`) and configuration (`terraform validate`)

### Deploy — `deploy.yml`

Triggered on push to `main` or manually via **Actions → Deploy Infrastructure and Artifacts → Run workflow**.

| Job | What it does |
|---|---|
| `terraform-plan` | Authenticates to Azure, runs `terraform init` + `terraform plan` |
| `terraform-apply` | Runs `terraform apply` (only when `apply=true` is selected) |
| `deploy-api` | Zips `api/`, `config/`, `data/`, `fabric/powerbi/` and deploys to API App Service |
| `deploy-ui` | Builds the Ionic Angular app, zips the output, and deploys to UI App Service |
| `deploy-fabric-components` | Resumes Fabric capacity, creates/verifies workspace, creates semantic model and pipeline via Fabric REST API, uploads data files to blob storage |

To provision and deploy from scratch:

1. Set all GitHub secrets listed above.
2. Go to **Actions → Deploy Infrastructure and Artifacts → Run workflow**.
3. Select **apply = true** and click **Run workflow**.

### Data Upload — `upload-employee-assets.yml`

Uploads employee asset files from `data/employees/` to the `employee-knowledge-raw` blob container. Triggered manually or on pushes that modify `data/employees/`.

### Local Deploy (Linux/macOS)

```bash
# Prerequisites: az CLI logged in, terraform installed, python 3.9+
bash scripts/deploy.sh --subscription YOUR_SUBSCRIPTION_ID
```

### Local Deploy (Windows)

```powershell
.\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUBSCRIPTION_ID"
```

Both scripts run `terraform init && terraform apply` for infrastructure, then the data-prep Python script, then optionally upload data files to blob storage.

### Data Preparation (standalone)

```bash
pip install pandas
python scripts/populate_fabric_complete.py
```

Loads JSON source files, validates records, generates `fabric/ontology/fabric_iq_ontology_complete.json` and `fabric/pipelines/employee_knowledge_pipeline_complete.json`, and exports CSV files to `data/exports/parquet/`.

---

## API Reference

Base URL: `https://<api_app_service_name>.azurewebsites.net`

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check — returns `200 OK` |
| `GET` | `/docs` | Interactive Swagger UI |
| `GET` | `/swagger.json` | OpenAPI spec |
| `GET` | `/api/summary` | Record counts for all entities |
| `GET` | `/api/employees` | All 100 employee records |
| `GET` | `/api/contributions` | All 100 contribution records |
| `GET` | `/api/digital-assets` | All 800 digital asset records |
| `GET` | `/api/projects` | All 20 project records |
| `GET` | `/api/org-hierarchy` | Organisation hierarchy tree |
| `GET` | `/api/powerbi-reports` | Power BI report metadata |
| `GET` | `/api/parsed-documents` | Parsed document records from Cosmos DB |
| `GET` | `/api/config/endpoints` | Current `endpoints.json` values |

See [api/README.md](api/README.md) for request/response schemas.

---

## Monitoring

All observability resources are provisioned by `terraform/monitors.tf` — no manual setup needed.

| Resource | Purpose |
|---|---|
| **Log Analytics Workspace** | Central log sink for all diagnostics |
| **Diagnostic Settings** | Blob storage read/write/delete logs, Cosmos DB data-plane and query logs, App Service HTTP and app logs |
| **Alert: Storage Availability** | Fires when blob storage availability drops below 99% |
| **Alert: Cosmos 5xx Errors** | Fires on > 5 server errors in 5 minutes |
| **Alert: Cosmos RU Throttling** | Fires on > 10 HTTP 429 responses in 5 minutes |
| **Alert: UI HTTP 5xx** | Fires on > 5 App Service 5xx responses in 5 minutes |
| **Alert: UI Response Time** | Fires when average response time exceeds 5 seconds |
| **Alert: Low Confidence Docs** | Scheduled query — fires when > 10 parsed docs have confidence < 0.5 in the last hour |
| **Logic App** | Receives Azure Monitor webhook, logs incidents to Cosmos DB `Incidents` container, and posts a Teams notification |

Configure the alert recipients by setting `sre_alert_email` and `sre_webhook_url` in `config/terraform.tfvars.json` before applying Terraform.

---

## License

See [LICENSE](LICENSE) for details.
