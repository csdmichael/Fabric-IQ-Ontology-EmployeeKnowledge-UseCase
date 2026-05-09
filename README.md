# Microsoft Fabric IQ – Employee Knowledge Graph Demo

## Table of Contents
- [Project Description](#project-description)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Technologies Used](#technologies-used)
- [Configuration Strategy (No Hardcoding)](#configuration-strategy-no-hardcoding)
- [Synthetic Data Design](#synthetic-data-design)
- [Employee Asset Generation](#employee-asset-generation)
- [Upload Workflow – Datasource Ingestion](#upload-workflow--datasource-ingestion)
- [Data Pipeline in Microsoft Fabric](#data-pipeline-in-microsoft-fabric)
- [Document Intelligence & Confidence Scoring](#document-intelligence--confidence-scoring)
- [Semantic Model & ERD](#semantic-model--erd)
- [Fabric IQ Ontology](#fabric-iq-ontology)
- [Fabric Data Agent](#fabric-data-agent)
- [Ionic + Angular + TypeScript UI](#ionic--angular--typescript-ui)
- [Teams & Copilot Agent Packaging Steps](#teams--copilot-agent-packaging-steps)
- [GitHub Workflows](#github-workflows)
- [Terraform Deployment](#terraform-deployment)
- [Best Practices](#best-practices)
- [License](#license)

## Project Description
This repository provides a complete **demo blueprint** for implementing an **Employee Knowledge Graph** use case with **Microsoft Fabric IQ**.  
It includes:
- Config-driven endpoints and runtime settings
- Synthetic enterprise data for 100 employees and digital assets
- Fabric-style dataflow/pipeline artifacts
- Document intelligence parsing outputs with section/document confidence
- OneLake semantic-model definitions and ontology mapping
- Fabric Data Agent prompt pack (20 prompts)
- Ionic/Angular/TypeScript UI scaffold with responsive layouts (web/tablet/mobile)

## Architecture
![Architecture Diagram](docs/architecture-diagram.svg)

## Folder Structure
```text
.
├── config/
│   ├── endpoints.json
│   ├── fabric-settings.json
│   ├── ontology-config.json
│   ├── workflows.json          # CI, deploy, and upload settings
│   └── terraform.tfvars.json
├── .github/workflows/
│   ├── ci.yml
│   ├── deploy.yml
│   └── upload-employee-assets.yml
├── data/
│   ├── employees.json
│   ├── digital_assets.json     # 600 assets (pptx, pdf, docx, txt, one, xlsx)
│   ├── emails.json
│   ├── org_hierarchy.json
│   ├── parsed_documents_cosmosdb.json
│   ├── storage_map.json
│   └── employees/              # generated actual asset files
│       ├── EMP001/
│       │   ├── EML-EMP001.eml
│       │   ├── AST-EMP001-01.pptx
│       │   ├── AST-EMP001-02.pdf
│       │   ├── AST-EMP001-03.docx
│       │   ├── AST-EMP001-04.txt
│       │   ├── AST-EMP001-05.one
│       │   └── AST-EMP001-06.xlsx
│       └── … (EMP002–EMP100 same structure)
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
- `config/endpoints.json`: Azure + Fabric + integration URLs/IDs
- `config/fabric-settings.json`: ingestion behavior, thresholds, storage names
- `config/ontology-config.json`: ontology name, entities, and relationship catalog

UI and pipeline artifacts reference config files rather than embedding environment values directly.

Config key resolution examples:
- `azure.blobStorageEndpoint` → Azure Blob endpoint template in `config/endpoints.json`
- `azure.documentIntelligenceEndpoint` → Document Intelligence endpoint in `config/endpoints.json`
- `azure.cosmosDbEndpoint` → Cosmos DB endpoint in `config/endpoints.json`
- `microsoftFabric.workspaceId` / `microsoftFabric.lakehouseId` → OneLake workspace/lakehouse IDs

## Synthetic Data Design
Data includes **100 employees** and enterprise digital assets expected in Lam Research-like environments:
- OneDrive assets in multiple formats: **pptx, pdf, docx, txt, one (OneNote), xlsx**
- Employee email records and ownership metadata
- Reporting hierarchy with manager mappings
- Azure storage paths mapped for raw/processed zones and OneLake target paths

Primary data files:
- `data/employees.json`
- `data/digital_assets.json` – 600 assets total (6 per employee): pptx, pdf, docx, txt, one, xlsx
- `data/emails.json`
- `data/org_hierarchy.json`
- `data/storage_map.json`
- `data/parsed_documents_cosmosdb.json` – 600 parsed document records

## Employee Asset Generation

The `data/employees/` folder contains **700 actual files** (7 per employee × 100 employees) generated from the JSON data sources.

### File types per employee

| File | Type | Description |
|------|------|-------------|
| `EML-EMPXXX.eml` | Email | RFC 2822 weekly status update email |
| `AST-EMPXXX-01.pptx` | Presentation | 4-slide PowerPoint deck (title + 3 content slides) |
| `AST-EMPXXX-02.pdf` | PDF | Process compliance document |
| `AST-EMPXXX-03.docx` | Word | Design specification document with metadata table |
| `AST-EMPXXX-04.txt` | Text | Shift handoff notes |
| `AST-EMPXXX-05.one` | OneNote | Notebook export (ZIP container with markdown + manifest) |
| `AST-EMPXXX-06.xlsx` | Spreadsheet | Department-specific data tracker with styled headers |

All file content is **department-aware** – Manufacturing employees get equipment OEE trackers, Finance employees get budget variance spreadsheets, R&D employees get experiment data logs, etc.

### Regenerating files

```bash
pip install python-pptx python-docx openpyxl reportlab
python scripts/generate_employee_files.py
```

The script is idempotent – it skips files that already exist. Delete individual files (or the whole `data/employees/` directory) to force regeneration.

### xlsx additions to JSON

`data/digital_assets.json` was extended with 100 `AST-EMPXXX-06` spreadsheet entries (one per employee) and `data/parsed_documents_cosmosdb.json` was extended with matching parse records. Both files now contain **600 entries each**.

## Upload Workflow – Datasource Ingestion

The workflow `.github/workflows/upload-employee-assets.yml` uploads all employee assets from `data/employees/` to the Azure Blob Storage container that the Fabric data pipeline monitors.

### How it works

1. **`load-config` job** – reads _all_ configuration from config files (zero hardcoded values):
   - `config/workflows.json` → Python version, local assets path, secret names, Azure CLI version
   - `config/fabric-settings.json` → target blob container (`storage.inputContainer`)
   - `data/storage_map.json` → blob path template (`onedriveIngestionPathTemplate`)
2. **`upload-assets` job** – authenticates with Azure via OIDC, then uploads every file to `{container}/{employeeId}/{filename}` using Azure CLI.

### Triggers

| Trigger | Behaviour |
|---------|-----------|
| `push` to `main` (paths: `data/employees/**`) | Automatically uploads changed assets |
| `workflow_dispatch` with `dry_run: false` | Manual full upload |
| `workflow_dispatch` with `dry_run: true` | Lists files that would be uploaded without uploading |

### Required GitHub secrets

| Secret name | Description |
|-------------|-------------|
| `AZURE_CREDENTIALS` | Azure service principal JSON (for `azure/login`) |
| `AZURE_STORAGE_ACCOUNT` | Storage account name (no endpoint URL – just the account name) |

The secret _names_ themselves are read from `config/workflows.json` (`upload.azureCredentialsSecretName` and `upload.storageAccountSecretName`) so they can be changed without editing the workflow YAML.

### Configuration reference (`config/workflows.json → upload`)

```jsonc
"upload": {
  "pythonVersion": "3.12",          // Python version for the runner
  "localAssetsPath": "data/employees",  // relative path to asset files
  "fabricSettingsFile": "config/fabric-settings.json",  // container name source
  "storageMapFile": "data/storage_map.json",            // path template source
  "azureCliVersion": "2.x",
  "azureCredentialsSecretName": "AZURE_CREDENTIALS",    // GitHub secret name
  "storageAccountSecretName": "AZURE_STORAGE_ACCOUNT"  // GitHub secret name
}
```

## Data Pipeline in Microsoft Fabric
![Data Pipeline Diagram](docs/data-pipeline-diagram.svg)

Pipeline artifacts:
- `fabric/dataflows/employee_ingestion_dataflow.json`
- `fabric/pipelines/employee_knowledge_pipeline.json`

Flow summary:
1. Ingest from Azure Blob/File into OneLake staging
2. Run classification/parsing with Document Intelligence
3. Persist parse JSON to Cosmos DB
4. Load curated data into OneLake
5. Refresh semantic model for analytics and agent experiences

## Document Intelligence & Confidence Scoring
Parsed output is persisted in:
- `data/parsed_documents_cosmosdb.json`

Each document record includes:
- `documentConfidence`
- `sectionConfidence.metadata`
- `sectionConfidence.content`
- `sectionConfidence.entities`
- employee ownership and classification category

This enables confidence rollups **by field section and by document**.

Default threshold note:
- `config/fabric-settings.json` sets `confidenceThreshold` to `0.72` as a balanced demo baseline.
- Increase threshold for stricter quality gating; lower it when recall/coverage is more important.

## Semantic Model & ERD
![Semantic Model ERD](docs/semantic-model-erd.svg)

Semantic model definition:
- `fabric/semantic-model/employee_knowledge_semantic_model.json`

Fact/Dimension layout:
- Facts: parsing confidence, employee asset activity
- Dimensions: employee, department, asset type, date

## Fabric IQ Ontology
![Ontology Diagram](docs/ontology-diagram.svg)

Ontology artifacts:
- `fabric/ontology/fabric_iq_ontology.json`
- `config/ontology-config.json`

Core business entities are linked to OneLake graph-oriented tables for query and agent grounding.

## Fabric Data Agent
Data agent package metadata is defined in:
- `fabric/agents/employee_knowledge_agent.json`

Includes **20 sample prompts** for employee-knowledge analysis (copy/execute scenarios for chat UX).

## Ionic + Angular + TypeScript UI
UI scaffold is located in:
- `ui/ionic-angular/`

Implemented pages with left navigation:
- Data Sources (employee assets + org hierarchy)
- Ingestion & Intelligence (Fabric flow + parsing layer)
- Data Agent Prompts (copy/execute prompt interactions)
- Agent Packaging (zip export + Teams/Copilot import)

Responsive behavior is included for:
- **Web** (3-column content emphasis)
- **Tablet** (2-column layout)
- **Mobile** (single-column stack)

Preview page for quick visual:
- `docs/ui-preview.html`

UI screenshot:
![UI Screenshot](docs/ui-screenshot.png)

## Teams & Copilot Agent Packaging Steps
1. Export agent definition from `fabric/agents/employee_knowledge_agent.json`
2. Package as `FabricEmployeeKnowledgeAgent.zip`
3. Open Teams Developer Portal: <https://dev.teams.microsoft.com>
4. Import the zip package as a custom agent/app
5. Validate prompt execution and data access permissions
6. Publish for Teams and Microsoft Copilot usage

## GitHub Workflows
Workflows are split for fast, dependency-aware execution:

- `.github/workflows/ci.yml`
  - `load-config` job reads all workflow/runtime settings from `config/workflows.json`
  - Parallel validation jobs:
    - `validate-json`
    - `validate-ui-scaffold`
    - `terraform-fmt-validate`

- `.github/workflows/deploy.yml`
  - `load-config` reads deploy settings from `config/workflows.json`
  - `package-fabric-bundle` and `terraform-plan` run in parallel
  - `terraform-apply` runs only when `workflow_dispatch` input `apply=true` and after dependencies succeed

- `.github/workflows/upload-employee-assets.yml`
  - `load-config` reads upload settings from `config/workflows.json`, `config/fabric-settings.json`, and `data/storage_map.json`
  - `upload-assets` authenticates with Azure via OIDC and uploads all files under `data/employees/` to the configured Azure Blob container
  - Supports `dry_run` mode (lists files without uploading)
  - Triggered automatically on `push` to `main` when files under `data/employees/**` change

All component-specific workflow configuration is centralized in:
- `config/workflows.json`

## Terraform Deployment
Terraform resources are in `terraform/` and use variables from:
- `config/terraform.tfvars.json`

Provisioned components:
- Azure Resource Group
- Azure Storage Account + raw/processed containers
- Azure Cosmos DB account + SQL database + SQL container

Typical commands:
```bash
cd terraform
terraform init
terraform plan -var-file=../config/terraform.tfvars.json
terraform apply -var-file=../config/terraform.tfvars.json
```

## Best Practices
- Keep endpoints and IDs in `/config` only
- Keep workflow behavior/runtime values in `config/workflows.json` instead of workflow YAML
- Use staged zones (raw → processed → curated) in OneLake
- Track confidence metrics for governance and reprocessing
- Separate semantic model and ontology concerns for maintainability
- Maintain prompt catalog for reusable business query patterns
- Keep UI responsive and task-oriented for different device classes

## License
See [LICENSE](LICENSE).
