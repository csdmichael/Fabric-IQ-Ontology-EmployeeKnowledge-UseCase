# Microsoft Fabric IQ – Employee Knowledge Graph

A complete demo solution that builds an employee knowledge graph using **Microsoft Fabric**, **Azure AI Document Intelligence**, **Azure AI Search**, **Microsoft Graph**, **Azure OpenAI**, **Power BI**, and a **FastAPI** backend — all provisioned and deployed through **Terraform** and **GitHub Actions**.

---

## Table of Contents

1. [Architecture](#architecture)
2. [Public URLs](#public-urls)
3. [Data Flow](#data-flow)
4. [Services Overview](#services-overview)
5. [Ontology & Data Model](#ontology--data-model)
6. [UI Overview](#ui-overview)
7. [Technologies](#technologies)
8. [Repository Structure](#repository-structure)
9. [Quick Start](#quick-start)
10. [Configuration](#configuration)
11. [Deployment](#deployment)
12. [API Reference](#api-reference)
13. [Monitoring](#monitoring)
14. [License](#license)

---

## Architecture

The solution implements a four-layer enterprise knowledge architecture:

![Architecture Diagram](https://github.com/user-attachments/assets/68b19276-08b7-49f4-833e-c02e558a51e5)

| Layer | Components |
|---|---|
| **Data Sources & Ingestion** | M365 (SharePoint, Teams, Outlook) via **Microsoft Graph Connectors** · External SaaS (ServiceNow, Jira, Salesforce) · Custom Apps & SQL DBs via **Azure Data Factory / Fabric Dataflow Gen2** · Physical/Legacy Docs via **Azure AI Document Intelligence** |
| **Knowledge Layer** | **Microsoft Fabric OneLake** (Raw → Bronze → Silver → Curated zones) · **Microsoft Purview Unified Catalog** (governance, lineage, metadata) · **Fabric Ontologies / Semantic Link** |
| **Intelligence & Reasoning** | **Azure AI Search** (semantic + vector indexing) · **Azure OpenAI Service** (RAG engine, GPT-4o, text-embedding-ada-002) · **Microsoft Graph** (relationship traversal) |
| **User Experience** | **Microsoft 365 Copilot** (personalized answers, expert identification) · **Viva Engage** (Answers in Viva) · **Microsoft Search** · **Viva Insights** · **Teams** |

---

## Public URLs

These are the internet-accessible URLs for demoing the solution:

| Resource | URL |
|---|---|
| **UI (Web App)** | `https://fabric-iq-emp-knowledge-ui.azurewebsites.net` |
| **API Base URL** | `https://fabric-iq-emp-knowledge-api.azurewebsites.net` |
| **Swagger UI** | `https://fabric-iq-emp-knowledge-api.azurewebsites.net/docs` |
| **OpenAPI Spec** | `https://fabric-iq-emp-knowledge-api.azurewebsites.net/swagger.json` |
| **API Health Check** | `https://fabric-iq-emp-knowledge-api.azurewebsites.net/health` |
| **APIM Gateway** | `https://ai-gateway-apim-poc-my.azure-api.net` |

> All URLs are also stored in `config/endpoints.json` and `config/service-config.json` under the `hosting` key.

---

## Data Flow

The diagram below shows how data moves from source documents and M365 through Azure services into Power BI.

![Data Pipeline Diagram](docs/data-pipeline-diagram.png)

```
M365 Data (SharePoint, Teams, Outlook)
        │  [Microsoft Graph Connectors]
        ▼
Physical/Legacy Docs (PDF, PPTX, XLSX, DOCX)
        │  [Azure AI Document Intelligence → JSON extraction]
        ▼
Azure Blob Storage  (employee-knowledge-raw container)
        │  [upload-employee-assets workflow / Fabric Dataflow Gen2]
        ▼
Fabric OneLake — Raw Zone
        │  [Bronze Stage: structured ingestion]
        ▼
OneLake — Bronze (Structured)
        │  [Silver Stage: curation, metadata enrichment]
        ▼
OneLake — Silver/Curated
        │  [Purview: governance & lineage | Fabric Ontologies: semantic link]
        ▼
Azure AI Search  (semantic + vector index, 1536-dim embeddings)
        │  [text-embedding-ada-002 via Azure OpenAI]
        ▼
Azure OpenAI Service  (RAG — GPT-4o + AI Search context)
        │
        ▼
FastAPI  (/api/* endpoints) → Ionic Angular UI
        │
        ▼
Power BI Reports & Dashboards  (3 reports, 11 visuals)
        │
        ▼
Microsoft 365 Copilot / Viva Engage / Microsoft Search
```

---

## Services Overview

### Azure AI Document Intelligence

Extracts structured JSON from employee knowledge documents — PDFs, PowerPoint decks, Excel spreadsheets, and Word documents. Results are stored in **Cosmos DB** (`EmployeeDocumentParsing` container) and indexed in **Azure AI Search**.

- **Endpoint**: configured in `config/service-config.json` → `documentIntelligence.endpoint`
- **Supported formats**: `pdf`, `docx`, `pptx`, `xlsx`, `png`, `jpg`, `tiff`
- **Models used**: `prebuilt-layout` (forms, tables, key-value pairs), `prebuilt-document` (paragraphs, entities)
- **Extraction outputs**: tables, key-value pairs, paragraphs, languages, barcodes
- **API route**: `GET /api/document-intelligence`
- **UI page**: `/document-intelligence`
- **Sample data**: `data/document_intelligence_results.json`

### Microsoft Graph

Ingests M365 data — **SharePoint** files, **OneDrive** documents, **Outlook** emails, **Teams** activity, and **Calendar** events — into OneLake via **Graph Connectors** and **Fabric Dataflow Gen2**.

- **Endpoint**: `https://graph.microsoft.com/v1.0` — configured in `config/service-config.json` → `microsoftGraph`
- **Scopes**: `User.Read.All`, `Mail.Read`, `Files.Read.All`, `Calendars.Read`, `Sites.Read.All`, `Team.ReadBasic.All`
- **Resources ingested**: users, driveItems (SharePoint/OneDrive), messages (Outlook), events, teams
- **API route**: `GET /api/graph-data`
- **UI page**: `/ms-graph`
- **Sample data**: `data/graph_data.json`

### Azure AI Search

Provides **semantic and vector indexing** over all employee knowledge assets. The index is powered by **text-embedding-ada-002** (1536-dim vectors) and enriched via an **AI Skillset** (entity recognition, key-phrase extraction, language detection, Document Intelligence enrichment).

- **Endpoint**: configured in `config/service-config.json` → `aiSearch.endpoint`
- **Index name**: `employee-knowledge-index`
- **Query types**: hybrid (BM25 + vector), semantic re-ranking
- **Facets**: department, format, documentType
- **Indexer schedule**: hourly (Cosmos DB change feed source)
- **API route**: `GET /api/ai-search`
- **UI page**: `/ai-search`
- **Sample data**: `data/ai_search_results.json`

### Azure OpenAI Service

Powers the **RAG engine** — combining AI Search results with **GPT-4o** to deliver personalized, relevant answers about employees, projects, and expertise. Also generates `text-embedding-ada-002` vectors used by AI Search.

- **Endpoint**: configured in `config/service-config.json` → `openAI.endpoint`
- **Deployment**: `gpt-4o` for chat, `text-embedding-ada-002` for embeddings

### Microsoft Fabric OneLake

Central knowledge layer with four zones (Raw → Bronze → Silver → Curated). Data flows from Blob Storage, Graph Connectors, and Document Intelligence results into OneLake tables.

- **Tables**: `employees`, `digital_assets`, `contributions`, `projects`, `org_hierarchy`, `parsed_documents`, `graph_items`, `search_index_log`
- **Workspace ID**: configured in `config/endpoints.json` → `microsoftFabric.workspaceId`
- **Lakehouse ID**: configured in `config/endpoints.json` → `microsoftFabric.lakehouseId`

### Microsoft Purview

Manages **governance, lineage, and metadata** across all data assets. Exposes business terminology via the Unified Catalog and enforces data classification policies.

- **Endpoint**: configured in `config/service-config.json` → `purview.catalogEndpoint`

---

## Ontology & Data Model

The knowledge graph models employees and their relationships to projects, digital assets, contributions, and parsed documents.

![Ontology Diagram](docs/ontology-diagram.png)

![Semantic Model ERD](docs/semantic-model-erd.png)

### Tables

| Table | Records | Primary Key | Description |
|---|---|---|---|
| **Employees** | 100 | `employeeId` | Name, department, role, skills, tier, email |
| **Contributions** | 100 | `employeeId` | Contribution score, project count, asset count, tier |
| **DigitalAssets** | 800 | `assetId` | Owner, type, title, last modified date |
| **Projects** | 20 | `projectId` | Name, status, lead, description |
| **ParsedDocuments** | varies | `documentId` | Document Intelligence extraction results |
| **GraphItems** | varies | `graphItemId` | Microsoft Graph files and emails |

### Relationships

```
Contributions[employeeId]  →  Employees[employeeId]   (many-to-one)
DigitalAssets[employeeId]  →  Employees[employeeId]   (many-to-one)
ParsedDocuments[employeeId]→  Employees[employeeId]   (many-to-one)
GraphItems[employeeId]     →  Employees[employeeId]   (many-to-one)
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

The Ionic Angular frontend provides dashboards, employee directory, org chart, leaderboard, Power BI report links, Document Intelligence viewer, Microsoft Graph explorer, AI Search results, and an AI agent chat interface.

![UI Screenshot](docs/ui-screenshot.png)

Navigation is organised into four sections:

| Section | Pages |
|---|---|
| **Source Data** | Employees, Org Structure, Projects, Digital Assets |
| **Reports & Dashboards** | Leaderboard, Power BI Reports, Ingestion Pipeline |
| **AI & Data Services** | Document Intelligence, Microsoft Graph, AI Search |
| **AI Agents** | Employee Copilot Agent, Agent Prompts, Agent Packaging |

---

## Technologies

| Technology | Role |
|---|---|
| **Microsoft Fabric** | Workspace, OneLake lakehouse, data pipeline, semantic model, ontology, Fabric Dataflow Gen2 |
| **Azure AI Document Intelligence** | Extracts structured JSON from PDF, PPTX, XLSX, DOCX, and image files; results stored in Cosmos DB |
| **Azure AI Search** | Semantic + vector indexing (1536-dim) of all employee knowledge assets; hybrid BM25 + vector queries |
| **Microsoft Graph** | Ingests M365 data (SharePoint, OneDrive, Outlook, Teams, Calendar) via Graph Connectors |
| **Azure OpenAI Service** | GPT-4o RAG engine + text-embedding-ada-002 vector generation |
| **Microsoft Purview** | Unified Catalog for governance, lineage, and metadata across OneLake, Cosmos DB, and Blob Storage |
| **Power BI** | Analytical reports and dashboards built on the Fabric semantic model |
| **Azure App Service** | Hosts the FastAPI backend (`api`) and Ionic Angular frontend (`ui`) |
| **Azure Blob Storage** | Stores raw and processed employee asset files; Fabric pipeline ingestion source |
| **Azure Cosmos DB** | Stores parsed employee documents, SRE incident records, Graph item metadata |
| **Azure Monitor** | Metric alerts, Log Analytics workspace, Logic App for automated SRE incident response |
| **Azure API Management** | Gateway for AI service calls — rate limiting, auth, monitoring |
| **FastAPI (Python 3.12)** | REST API serving all employee data, document intelligence, graph data, AI search, and config |
| **Ionic Angular** | Single-page web app providing the UI |
| **Terraform** | Infrastructure as Code for all Azure resources |
| **GitHub Actions** | CI validation, Terraform plan/apply, API/UI deployment, employee asset upload, smoke tests |

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

config/                         # ← All IDs, endpoints, and settings live here (no secrets)
  endpoints.json                # Fabric workspace/lakehouse/model IDs and Azure URLs
  service-config.json           # All service configs: Document Intelligence, Graph, AI Search, OpenAI, hosting URLs
  azure-hosting-resources.json  # Resource group, app names, networking (read by deploy.yml)
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
  document_intelligence_results.json  # Document Intelligence JSON extraction results (PDF, PPTX, XLS, DOCX)
  graph_data.json               # Microsoft Graph sample data (users, files, emails, Teams activity)
  ai_search_results.json        # Azure AI Search index stats, semantic query results, and facets
  storage_map.json              # Blob storage path config (read by upload workflow)
  exports/parquet/              # CSV exports for Fabric ingestion

docs/
  architecture-diagram.png      # Full solution architecture (4-layer: Data Sources → Knowledge → Intelligence → UX)
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
  generate_employee_files.py    # Generates 700 employee asset files (PDF, PPTX, XLSX, DOCX)
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
    src/app/pages/              # Page components:
      employees/                #   Employee directory with KPIs and project breakdown
      org-chart/                #   Organisation hierarchy tree
      leaderboard/              #   Contribution leaderboard with charts
      powerbi-reports/          #   Power BI report metadata
      data-sources/             #   Digital asset browser with file preview
      ingestion-flow/           #   Fabric pipeline stage visualisation
      document-intelligence/    #   Document Intelligence extraction viewer (PDF, PPTX, XLS, DOCX)
      ms-graph/                 #   Microsoft Graph data explorer (users, files, emails)
      ai-search/                #   Azure AI Search results, facets, and indexer config
      employee-agent/           #   Employee Copilot Agent chat interface
      agent-prompts/            #   30 sample agent prompts
      agent-package/            #   Agent packaging reference
    src/app/services/           # Config service (loads endpoints.json)
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
#    - config/service-config.json
#    - GitHub repository secrets

# 3. Push to main (triggers Terraform plan/apply + deploy)
git push origin main

# 4. (Optional) Trigger apply manually from GitHub Actions → Deploy → Run workflow → apply=true
```

After the workflow completes, your demo is live at these public URLs:

| URL | Description |
|---|---|
| `https://<ui_app_service_name>.azurewebsites.net` | Web UI |
| `https://<api_app_service_name>.azurewebsites.net/docs` | Swagger UI |
| `https://<api_app_service_name>.azurewebsites.net/swagger.json` | OpenAPI spec |
| `https://<api_app_service_name>.azurewebsites.net/health` | Health check |

---

## Configuration

**All configuration lives in `config/`.** Edit these files before the first deployment — no portal steps required. No secrets are stored in this folder; use GitHub Secrets or Azure Key Vault for credentials.

### `config/service-config.json` ← Primary config for all AI services

This is the single source of truth for all service endpoints, IDs, and settings. Reference it in your code with `GET /api/config/service-config`.

| Key path | Description |
|---|---|
| `documentIntelligence.endpoint` | Azure AI Document Intelligence endpoint URL |
| `documentIntelligence.supportedFormats` | List of file formats processed (pdf, docx, pptx, xlsx, …) |
| `documentIntelligence.defaultModel` | Default extraction model (`prebuilt-layout`) |
| `documentIntelligence.cosmosDbContainer` | Cosmos container for extracted results |
| `microsoftGraph.endpoint` | Microsoft Graph v1.0 API endpoint |
| `microsoftGraph.scopes` | Required OAuth2 permission scopes |
| `microsoftGraph.tenantId` | Azure AD tenant ID |
| `microsoftGraph.enabledResources` | M365 resource types to ingest |
| `aiSearch.endpoint` | Azure AI Search service endpoint |
| `aiSearch.indexName` | Search index name |
| `aiSearch.embeddingModel` | Embedding model for vector fields |
| `aiSearch.vectorDimensions` | Vector field dimensions (1536 for ada-002) |
| `aiSearch.semanticConfigurationName` | Semantic search configuration name |
| `openAI.endpoint` | Azure OpenAI / AI Foundry project endpoint |
| `openAI.deploymentName` | Chat model deployment name (gpt-4o) |
| `openAI.embeddingDeploymentName` | Embedding model deployment name |
| `fabricOneLake.workspaceId` | Fabric workspace GUID |
| `fabricOneLake.lakehouseId` | OneLake lakehouse GUID |
| `hosting.uiPublicUrl` | Public URL for the UI App Service |
| `hosting.apiPublicUrl` | Public URL for the API App Service |
| `hosting.swaggerUrl` | Swagger UI URL |

### `config/endpoints.json` — Fabric & Azure Endpoints

Update after the Fabric workspace is provisioned.

| Key path | Description |
|---|---|
| `microsoftFabric.workspaceId` | Fabric workspace GUID |
| `microsoftFabric.lakehouseId` | OneLake lakehouse GUID |
| `microsoftFabric.semanticModelId` | Power BI semantic model GUID |
| `azure.documentIntelligenceEndpoint` | Document Intelligence endpoint |
| `azure.aiSearchEndpoint` | AI Search service endpoint |
| `azure.cosmosDbEndpoint` | Cosmos DB endpoint |
| `hosting.uiPublicUrl` | Deployed UI URL |
| `hosting.apiUrl` | Deployed API URL |

### `config/terraform.tfvars.json` — Terraform Variables

| Variable | Description | Example |
|---|---|---|
| `resource_group_name` | Existing Azure resource group | `"ai-myaacoub"` |
| `storage_account_name` | Globally unique storage account name | `"stfabriciqdemodata01"` |
| `cosmos_account_name` | Globally unique Cosmos DB account name | `"cosmos-fabriciq-demo-01"` |
| `cosmos_database_name` | Cosmos DB database name | `"EmployeeKnowledgeGraph"` |
| `ui_app_service_name` | Azure App Service name for the UI | `"fabric-iq-emp-knowledge-ui"` |
| `api_app_service_name` | Azure App Service name for the API | `"fabric-iq-emp-knowledge-api"` |
| `app_service_plan_sku` | App Service SKU | `"B3"` |
| `sre_alert_email` | Email for Azure Monitor alert notifications | `"sre@example.com"` |

### `config/azure-hosting-resources.json` — Azure Resource Config

Read by the deploy workflow to know which resource group and App Service names to target.

| Key path | Description |
|---|---|
| `subscriptionId` | Azure subscription ID |
| `resourceGroup` | Resource group name |
| `hosting.apiWebApp.name` | API App Service name |
| `hosting.uiWebApp.name` | UI App Service name |
| `dataAndAi.aiSearch` | AI Search service name |
| `fabric.workspaceName` | Fabric workspace name |

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

### Employee Asset Generation

Regenerate the 700 employee asset files (PDF, PPTX, XLSX, DOCX) used as input to Document Intelligence:

```bash
pip install python-pptx python-docx openpyxl reportlab
python scripts/generate_employee_files.py
```

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

Uploads employee asset files from `data/employees/` to the `employee-knowledge-raw` blob container. These files are then processed by Azure AI Document Intelligence. Triggered manually or on pushes that modify `data/employees/`.

### Local Deploy (Linux/macOS)

```bash
# Prerequisites: az CLI logged in, terraform installed, python 3.9+
bash scripts/deploy.sh --subscription YOUR_SUBSCRIPTION_ID
```

### Local Deploy (Windows)

```powershell
.\scripts\deploy-complete-solution.ps1 -SubscriptionId "YOUR_SUBSCRIPTION_ID"
```

### Data Preparation (standalone)

```bash
pip install pandas
python scripts/populate_fabric_complete.py
```

---

## API Reference

Base URL: `https://<api_app_service_name>.azurewebsites.net`

| Method | Path | Description |
|---|---|---|
| `GET` | `/health` | Health check — returns `200 OK` |
| `GET` | `/docs` | Interactive Swagger UI |
| `GET` | `/swagger.json` | OpenAPI spec |
| `GET` | `/api/summary` | Record counts for all entities (includes doc intelligence, graph, search stats) |
| `GET` | `/api/employees` | All 100 employee records |
| `GET` | `/api/contributions` | All 100 contribution records |
| `GET` | `/api/digital-assets` | All 800 digital asset records |
| `GET` | `/api/projects` | All 20 project records |
| `GET` | `/api/org-hierarchy` | Organisation hierarchy tree |
| `GET` | `/api/powerbi-reports` | Power BI report metadata |
| `GET` | `/api/parsed-documents` | Parsed document metadata from Cosmos DB |
| `GET` | `/api/document-intelligence` | Document Intelligence JSON extraction results (PDF, PPTX, XLSX, DOCX) |
| `GET` | `/api/graph-data` | Microsoft Graph sample data (users, files, emails, Teams activity) |
| `GET` | `/api/ai-search` | Azure AI Search index stats, semantic query results, and facets |
| `GET` | `/api/config/endpoints` | Current `endpoints.json` values |
| `GET` | `/api/config/service-config` | All service configurations from `service-config.json` |

All list endpoints support optional `?department=<dept>` and `?employeeId=<id>` query parameters.

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
