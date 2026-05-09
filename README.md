# Microsoft Fabric IQ – Employee Knowledge Graph Demo

## Table of Contents
- [Project Description](#project-description)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Technologies Used](#technologies-used)
- [Configuration Strategy (No Hardcoding)](#configuration-strategy-no-hardcoding)
- [Deployment & Component URLs](#deployment--component-urls)
- [Synthetic Data Design](#synthetic-data-design)
- [Employee Asset Generation](#employee-asset-generation)
- [Project Data](#project-data)
- [Upload Workflow – Datasource Ingestion](#upload-workflow--datasource-ingestion)
- [Data Pipeline in Microsoft Fabric](#data-pipeline-in-microsoft-fabric)
- [Document Intelligence & Confidence Scoring](#document-intelligence--confidence-scoring)
- [Semantic Model & ERD](#semantic-model--erd)
- [Fabric IQ Ontology](#fabric-iq-ontology)
- [Fabric Data Agent](#fabric-data-agent)
- [Ionic + Angular + TypeScript UI](#ionic--angular--typescript-ui)
- [Reusable Azure Hosting Resources (ai-myaacoub)](#reusable-azure-hosting-resources-ai-myaacoub)
- [Managed Identity Setup](#managed-identity-setup)
- [Private Networking Model](#private-networking-model)
- [Prompt Catalog](#prompt-catalog)
- [Teams & Copilot Agent Packaging Steps](#teams--copilot-agent-packaging-steps)
- [GitHub Workflows](#github-workflows)
- [Terraform Deployment](#terraform-deployment)
- [Best Practices](#best-practices)
- [License](#license)

## Project Description
This repository provides a complete **demo blueprint** for implementing an **Employee Knowledge Graph** use case with **Microsoft Fabric IQ**.

It includes:
- Config-driven endpoints and runtime settings
- Synthetic enterprise data for 100 employees and multi-format digital assets
- Fabric-style dataflow/pipeline artifacts
- Document intelligence parsing outputs with section/document confidence
- OneLake semantic model definitions and ontology mapping
- Fabric Data Agent prompt pack with citation-ready prompts
- Ionic/Angular/TypeScript UI scaffold with responsive layouts and document browsing

## Architecture
![Architecture Diagram](docs/architecture-diagram.svg)

## Folder Structure
```text
.
├── config/
│   ├── azure-hosting-resources.json
│   ├── endpoints.json
│   ├── fabric-settings.json
│   ├── ontology-config.json
│   ├── workflows.json
│   └── terraform.tfvars.json
├── .github/workflows/
│   ├── ci.yml
│   ├── deploy.yml
│   └── upload-employee-assets.yml
├── data/
│   ├── employees.json
│   ├── digital_assets.json
│   ├── emails.json
│   ├── org_hierarchy.json
│   ├── projects.json
│   ├── parsed_documents_cosmosdb.json
│   ├── storage_map.json
│   └── employees/
├── scripts/
│   └── generate_employee_files.py
├── docs/
│   ├── architecture-diagram.svg
│   ├── data-pipeline-diagram.svg
│   ├── semantic-model-erd.svg
│   ├── ontology-diagram.svg
│   ├── prompts.txt
│   └── ui-preview.html
├── fabric/
│   ├── dataflows/
│   ├── pipelines/
│   ├── semantic-model/
│   ├── ontology/
│   └── agents/
├── ui/
│   └── ionic-angular/
├── terraform/
├── LICENSE
└── README.md
```

## Technologies Used
- **Microsoft Fabric** (OneLake, Pipelines, Dataflows, Semantic Models, Data Agent)
- **Azure Storage** (Blob/File landing zones)
- **Azure AI Document Intelligence / Content Understanding**
- **Azure Cosmos DB** (parsed JSON outputs)
- **Ionic + Angular + TypeScript** (UI)
- **JSON/SVG** artifacts for demo portability

## Configuration Strategy (No Hardcoding)
All platform endpoints and runtime options are centralized in `/config`:
- `config/endpoints.json`: Azure/Fabric/integration URLs and IDs
- `config/fabric-settings.json`: ingestion behavior, thresholds, and networking policy flags
- `config/azure-hosting-resources.json`: reusable existing hosting resources in `ai-myaacoub`
- `config/ontology-config.json`: ontology name, entities, and relationship catalog

## Deployment & Component URLs
| Component | URL / Link | Source |
|---|---|---|
| UI Web App | https://fabric-iq-emp-knowledge-ui.azurewebsites.net | `config/endpoints.json` (`hosting.uiPublicUrl`) |
| API Web App | https://foundry-privatevnet-api.azurewebsites.net | `config/endpoints.json` (`hosting.apiUrl`) |
| API Management Gateway | https://ai-gateway-apim-poc-my.azure-api.net | `config/endpoints.json` (`azure.apiManagementGateway`) |
| Azure Blob Storage Endpoint | https://aistoragemyaacoub.blob.core.windows.net | `config/endpoints.json` (`azure.blobStorageEndpoint`) |
| Azure File Storage Endpoint | https://aistoragemyaacoub.file.core.windows.net | `config/endpoints.json` (`azure.fileStorageEndpoint`) |
| Cosmos DB Endpoint | https://cosmos-ai-poc.documents.azure.com:443/ | `config/endpoints.json` (`azure.cosmosDbEndpoint`) |
| Azure AI Search Endpoint | https://aisearch-poc-myaacoub.search.windows.net | `config/endpoints.json` (`azure.aiSearchEndpoint`) |
| Azure Foundry Project Endpoint | https://002-ai-poc-private.services.ai.azure.com/api/projects/proj-default | `config/endpoints.json` (`azure.foundryProjectEndpoint`) |
| Fabric IQ Ontology Artifact | [fabric/ontology/fabric_iq_ontology.json](fabric/ontology/fabric_iq_ontology.json) | Repository artifact |
| Fabric Ontology Diagram | [docs/ontology-diagram.svg](docs/ontology-diagram.svg) | Repository documentation |
| Teams Developer Portal | https://dev.teams.microsoft.com | `config/endpoints.json` (`integration.teamsDevPortalUrl`) |
| Copilot Studio | https://copilotstudio.microsoft.com | `config/endpoints.json` (`integration.copilotStudioUrl`) |

## Synthetic Data Design
Data includes **100 employees** and enterprise digital assets expected in Lam Research-like environments.

Primary files:
- `data/employees.json`
- `data/digital_assets.json` – **800 assets total (8 per employee)**
- `data/emails.json` – **100 emails (1 per employee)**
- `data/org_hierarchy.json`
- `data/storage_map.json`
- `data/parsed_documents_cosmosdb.json` – **800 parse records**

## Employee Asset Generation
`data/employees/` now contains **900 generated files** total (9 per employee × 100 employees).

### File types per employee
| File | Type |
|------|------|
| `EML-EMPXXX.eml` | Email |
| `AST-EMPXXX-01.pptx` | Presentation |
| `AST-EMPXXX-02.pdf` | PDF |
| `AST-EMPXXX-03.docx` | Word |
| `AST-EMPXXX-04.txt` | Text |
| `AST-EMPXXX-05.one` | OneNote export |
| `AST-EMPXXX-06.xlsx` | Spreadsheet |
| `AST-EMPXXX-07.csv` | CSV metrics export |
| `AST-EMPXXX-08.md` | Markdown knowledge notes |

### Regenerating files
```bash
pip install python-pptx python-docx openpyxl reportlab
python scripts/generate_employee_files.py
```

## Project Data
`data/projects.json` contains **20 synthetic projects** spanning all departments and employee groups.

Each project record includes:
- `projectId` – unique identifier (e.g. `PRJ001`)
- `name` – descriptive project title
- `description` – business context and goals
- `department` – owning department (Manufacturing, R&D, IT, HR, Procurement, Operations, Finance)
- `status` – `Active`, `Completed`, or `Planning`
- `startDate` / `endDate` – ISO-8601 dates (endDate is `null` for ongoing projects)
- `employeeIds` – list of assigned employees (3–7 per project)
- `skills` – required skills matching the employee skill ontology

The ontology edge `Employee → CONTRIBUTES_TO → Project` is defined in:
- `fabric/ontology/fabric_iq_ontology.json`
- `config/ontology-config.json`

Project data is uploaded to `employee-knowledge-raw/projects.json` on Azure Blob Storage and ingested by the `IngestProjectData` pipeline activity.


## Upload Workflow – Datasource Ingestion
`.github/workflows/upload-employee-assets.yml` uploads all generated employee assets from `data/employees/` to Azure Blob Storage.

## Data Pipeline in Microsoft Fabric
![Data Pipeline Diagram](docs/data-pipeline-diagram.svg)

Flow summary:
1. Ingest from Azure Blob/File into OneLake staging
2. Run classification/parsing with Document Intelligence
3. Persist parse JSON to Cosmos DB
4. Load curated data into OneLake
5. Refresh semantic model for analytics and agent experiences

## Document Intelligence & Confidence Scoring
Parsed output is persisted in `data/parsed_documents_cosmosdb.json`.

Each document record includes:
- `documentConfidence`
- `sectionConfidence.metadata`
- `sectionConfidence.content`
- `sectionConfidence.entities`
- employee ownership and classification category

## Semantic Model & ERD
![Semantic Model ERD](docs/semantic-model-erd.svg)

Semantic model definition:
- `fabric/semantic-model/employee_knowledge_semantic_model.json`

## Fabric IQ Ontology
![Ontology Diagram](docs/ontology-diagram.svg)

Ontology artifacts:
- `fabric/ontology/fabric_iq_ontology.json`
- `config/ontology-config.json`

## Fabric Data Agent
Agent package metadata:
- `fabric/agents/employee_knowledge_agent.json`

The 20 sample prompts are now citation-oriented and explicitly instruct responses to include:
- `documentId`
- `cosmosDbRecordId`
- `storageRef.relativePath`

## Ionic + Angular + TypeScript UI
UI scaffold:
- `ui/ionic-angular/`

Implemented page capabilities:
- **Data Sources**: employee + asset search autocomplete, filtering, pagination, and asset list browsing
- **Projects**: browse 20 employee-linked projects; filter by department/status; view team assignments and required skills
- **Document Viewer**: in-browser preview flow for pptx/docx/pdf/one/txt/eml/csv/md (with format-aware rendering strategy)
- **Ingestion & Intelligence**: Fabric pipeline and intelligence layer narrative
- **Data Agent Prompts**: prompt interactions aligned with citation requirements
- **Agent Packaging**: Teams/Copilot packaging flow

Preview page:
- `docs/ui-preview.html`

## Reusable Azure Hosting Resources (ai-myaacoub)
This repository now includes reusable hosting/network metadata under:
- `config/azure-hosting-resources.json`

Configured references include:
- Resource group: `ai-myaacoub`
- UI web app: `fabric-iq-emp-knowledge-ui` (new, dedicated, public) — reuses `plan-taxforms` App Service Plan
- API web app: `foundry-privatevnet-api`
- APIM: `ai-gateway-apim-poc-my`
- AI Search: `aisearch-poc-myaacoub`
- Foundry account: `002-ai-poc-private`
- Cosmos DB: `cosmos-ai-poc`
- Storage account: `aistoragemyaacoub`
- Existing VNet and private endpoint naming guidance

## Managed Identity Setup
Use managed identities for app-to-data-plane access instead of secrets.

1. Enable **System Assigned Managed Identity** on app hosts (API/UI or backend workers).
2. Grant least-privilege RBAC on required resources:
   - Storage: `Storage Blob Data Reader/Contributor` as needed
   - Cosmos DB: `Cosmos DB Built-in Data Reader/Contributor` as needed
   - APIM/Foundry integrations: only required role scopes
3. Remove embedded credentials from app settings and use Entra token-based auth.
4. Validate token acquisition and resource access paths before production rollout.

## Private Networking Model
Private connectivity is expected for all data-plane services except UI exposure.

Policy flags are in `config/fabric-settings.json`:
- `networking.usePrivateEndpoints = true`
- `networking.useExistingVnet = true`
- `networking.uiInternetExposed = true`

Expected pattern:
- **Private**: Storage, Cosmos DB, AI Search, Foundry
- **Public**: UI endpoint only

## Prompt Catalog
Prompt requirements are consolidated and organized in:
- `docs/prompts.txt`

This file includes:
- Original baseline scope requirements
- New enhancement requirements
- Citation behavior requirements for prompts/agent responses

## Teams & Copilot Agent Packaging Steps
1. Export agent definition from `fabric/agents/employee_knowledge_agent.json`
2. Package as `FabricEmployeeKnowledgeAgent.zip`
3. Open Teams Developer Portal: <https://dev.teams.microsoft.com>
4. Import zip package as custom agent/app
5. Validate prompt execution and data access permissions
6. Publish for Teams and Microsoft Copilot usage

## GitHub Workflows
- `.github/workflows/ci.yml`: JSON/UI/Terraform validation checks
- `.github/workflows/deploy.yml`: deployment packaging and Terraform plan/apply flow
- `.github/workflows/upload-employee-assets.yml`: asset upload to Azure Blob, with dry-run mode

## Terraform Deployment
Terraform resources are in `terraform/` and use values from:
- `config/terraform.tfvars.json`

Typical commands:
```bash
cd terraform
terraform init
terraform plan -var-file=../config/terraform.tfvars.json
terraform apply -var-file=../config/terraform.tfvars.json
```

## Best Practices
- Keep endpoints and IDs in `/config` only
- Prefer managed identities over secret-based access
- Keep private endpoints and VNet boundaries for data-plane services
- Expose only UI publicly when required
- Track confidence metrics for governance and reprocessing
- Maintain a prompt catalog with explicit citation expectations
- Keep UI responsive and task-oriented for web/tablet/mobile

## License
See [LICENSE](LICENSE).
