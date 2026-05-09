# Fabric IQ Employee Knowledge – Demo Script

> **Version:** 1.0  
> **Author:** Michael Yaacoub – Microsoft  
> **Duration:** ~30–45 minutes (full demo) · ~15 minutes (abbreviated)  
> **Audience:** Customer technical stakeholders, solution architects, engineering teams

---

## Table of Contents
- [Prerequisites](#prerequisites)
- [Demo Environment Overview](#demo-environment-overview)
- [Act 1 – Architecture & Data Model Walk-Through](#act-1--architecture--data-model-walk-through)
- [Act 2 – Data Ingestion & Intelligence Pipeline](#act-2--data-ingestion--intelligence-pipeline)
- [Act 3 – Fabric Semantic Model & Ontology](#act-3--fabric-semantic-model--ontology)
- [Act 4 – UI Application Walk-Through](#act-4--ui-application-walk-through)
- [Act 5 – Fabric Data Agent & Prompt Catalog](#act-5--fabric-data-agent--prompt-catalog)
- [Act 6 – Azure Monitor & SRE Dashboard](#act-6--azure-monitor--sre-dashboard)
- [Act 7 – Incident Response Flow](#act-7--incident-response-flow)
- [Act 8 – Teams & Copilot Agent Packaging](#act-8--teams--copilot-agent-packaging)
- [Q&A Talking Points](#qa-talking-points)
- [Abbreviated Demo Path (15 min)](#abbreviated-demo-path-15-min)

---

## Prerequisites

Before starting the demo, verify the following are in place:

| Item | Status Check |
|------|-------------|
| Azure subscription access to `ai-myaacoub` RG | Log in to portal.azure.com |
| Terraform applied (`terraform apply` completed) | Run `terraform output` – all outputs visible |
| Employee assets uploaded to Azure Blob | Run `.github/workflows/upload-employee-assets.yml` |
| UI app deployed and accessible | Open `https://fabric-iq-emp-knowledge-ui.azurewebsites.net` |
| Fabric workspace configured | Open Microsoft Fabric → verify workspace and pipeline |
| Azure Monitor alerts active | Open portal → Monitor → Alerts → confirm 6 active rules |
| Logic App deployed | Open `logic-fabriciq-incident-response` → verify trigger URL |

### Quick Setup Commands

```bash
# 1. Generate employee asset files (if not already done)
pip install python-pptx python-docx openpyxl reportlab
python scripts/generate_employee_files.py

# 2. Deploy infrastructure
cd terraform
terraform init
terraform plan -var-file=../config/terraform.tfvars.json
terraform apply -var-file=../config/terraform.tfvars.json

# 3. Capture Logic App trigger URL and update webhook
terraform output -raw incident_response_logic_app_trigger_url
```

---

## Demo Environment Overview

**Key URLs to have open before starting:**

| Tab | URL | Purpose |
|-----|-----|---------|
| 1 | `https://fabric-iq-emp-knowledge-ui.azurewebsites.net` | Live UI Application |
| 2 | `https://app.fabric.microsoft.com` | Microsoft Fabric workspace |
| 3 | `https://portal.azure.com` | Azure portal (Monitor + resources) |
| 4 | This repository | Architecture diagrams + artifacts |

---

## Act 1 – Architecture & Data Model Walk-Through

**Duration:** 5 minutes  
**Goal:** Set the scene – explain the end-to-end architecture before touching the UI.

### Steps

1. **Open** `docs/architecture-diagram.svg` (or the PNG rendered in the README).

2. **Narrate** the architecture layers top to bottom:
   > "We start with 100 synthetic employees, each with 9 different file types: PowerPoint presentations, PDFs, Word documents, OneNote exports, plain text files, Excel spreadsheets, CSVs, Markdown notes, and email messages. These represent the kind of digital knowledge artifacts employees produce every day in a large organization."

3. **Point** to the Azure Blob/File Storage layer:
   > "All raw files land in Azure Blob Storage in the `employee-knowledge-raw` container, using private endpoints only. The UI is the only internet-facing surface."

4. **Point** to the Fabric pipeline layer:
   > "Microsoft Fabric pipelines ingest, classify, and parse every document using Azure AI Document Intelligence. Parse results – including confidence scores – are persisted to Cosmos DB as structured JSON."

5. **Point** to the Semantic Model + Ontology layer:
   > "Curated data in OneLake powers a Fabric semantic model and a custom IQ ontology that understands employee relationships, project contributions, skills, and organizational hierarchy."

6. **Point** to the Azure Monitor layer (bottom):
   > "And new in this release – every resource is monitored. Six Azure Monitor alert rules protect the platform 24/7, routing to an SRE action group with automated incident response via a Logic App HTTP trigger."

7. **Open** `docs/ontology-diagram.svg` briefly:
   > "The ontology defines the knowledge graph edges: Employee → WORKS_ON → Project, Employee → HAS_SKILL → Skill, Employee → REPORTS_TO → Employee, and so on. This is what makes the Fabric Data Agent intelligent."

---

## Act 2 – Data Ingestion & Intelligence Pipeline

**Duration:** 5 minutes  
**Goal:** Show the data pipeline and document intelligence outputs.

### Steps

1. **Open** Microsoft Fabric workspace (Tab 2).

2. **Navigate** to the Pipeline: `EmployeeKnowledgePipeline`.
   > "This pipeline has three main stages: ingestion from blob storage, Document Intelligence parsing, and Cosmos DB write-back."

3. **Show** the pipeline activity view – highlight:
   - `IngestEmployeeAssets` activity (blob read)
   - `ClassifyAndParseDocuments` activity (Doc Intelligence)
   - `PersistParseResults` activity (Cosmos DB write)
   - `IngestProjectData` activity (projects JSON)

4. **Switch** to the Azure portal and open `cosmos-fabriciq-demo-01` → **Data Explorer** → `EmployeeKnowledgeGraph` → `EmployeeDocumentParsing`.

5. **Run** a sample query:
   ```sql
   SELECT TOP 5 c.employeeId, c.documentId, c.documentConfidence,
          c.sectionConfidence.content, c.sectionConfidence.entities
   FROM c
   WHERE c.documentConfidence > 0.8
   ORDER BY c.documentConfidence DESC
   ```

6. **Show** the confidence structure:
   > "Each parse record includes a document-level confidence and section-level breakdowns for metadata, content, and entities. This drives both agent responses and governance flagging."

7. **Open** `data/parsed_documents_cosmosdb.json` to show the 800-record structure.

---

## Act 3 – Fabric Semantic Model & Ontology

**Duration:** 5 minutes  
**Goal:** Demonstrate the knowledge graph model and ontology.

### Steps

1. **Open** `docs/semantic-model-erd.svg` in the README.
   > "The semantic model defines relationships between Employees, Projects, Assets, Parse Records, and Org Hierarchy – all queryable through the Fabric Data Agent."

2. **Open** `fabric/ontology/fabric_iq_ontology.json` and show the entity and relationship definitions.
   > "The IQ ontology maps these entities and edges formally. For example: the `CONTRIBUTES_TO` edge links employees to projects, and `HAS_SKILL` links employees to their skills."

3. **Open** `fabric/semantic-model/employee_knowledge_semantic_model.json` briefly:
   > "The semantic model is config-driven, with no hardcoded IDs – all workspace and lakehouse references flow from `config/endpoints.json`."

4. **Open** `data/projects.json` – scroll through a few projects:
   > "We have 20 synthetic projects spanning 7 departments: Manufacturing, R&D, IT, HR, Procurement, Operations, Finance. Each project has 3–7 assigned employees and required skills."

---

## Act 4 – UI Application Walk-Through

**Duration:** 8 minutes  
**Goal:** Demonstrate the full Ionic/Angular UI.

### Steps

#### 4a. Data Sources Page

1. **Open** the UI (Tab 1) → navigate to **Data Sources**.
2. **Type** an employee name in the search autocomplete:
   > "The search autocomplete filters across 100 employees and their 900 associated assets in real time."
3. **Select** an employee → show their 9 assets listed with format icons.
4. **Use pagination** to browse additional employees.
5. **Click** a PDF or PPTX asset → demonstrate the in-browser Document Viewer.
   > "The document viewer renders PDFs natively, PowerPoint slides as image stacks, Word docs as formatted HTML, OneNote exports as structured text, and CSV data as a table."

#### 4b. Projects Page

1. **Navigate** to **Projects**.
2. **Filter** by department (e.g., "R&D") and status ("Active").
3. **Click** a project → show team members, required skills, and project timeline.
   > "The project view follows the ontology edge: each employee link shows their skill match to the project requirements."

#### 4c. Ingestion & Intelligence Page

1. **Navigate** to **Ingestion & Intelligence**.
2. **Walk through** the pipeline narrative and confidence score visualization.
   > "This page gives stakeholders visibility into the ingestion status and Document Intelligence confidence distribution across all 800 parsed documents."

#### 4d. Data Agent Prompts Page

1. **Navigate** to **Data Agent Prompts**.
2. **Show** the prompt catalog – highlight the citation requirement.
3. **Click** a prompt to copy it → switch to Fabric (Tab 2) → paste into the Data Agent.
   > "Every prompt is designed to produce structured responses that include documentId, cosmosDbRecordId, and the storage path – full traceability from answer back to source."

#### 4e. Agent Packaging Page

1. **Navigate** to **Agent Packaging**.
2. **Walk through** the Teams packaging steps shown in the UI.
   > "The agent JSON from `fabric/agents/employee_knowledge_agent.json` can be zipped and imported into the Teams Developer Portal to deploy as a custom Copilot agent."

---

## Act 5 – Fabric Data Agent & Prompt Catalog

**Duration:** 5 minutes  
**Goal:** Live-fire sample prompts against the Data Agent.

### Sample Prompts to Execute

Copy each prompt into the Fabric Data Agent in your workspace and show the response.

**Prompt 1 – Employee skill lookup:**
```
List all employees with expertise in Python and Machine Learning.
Include their documentId and cosmosDbRecordId for each supporting asset.
```

**Prompt 2 – Project team composition:**
```
Which employees are assigned to the Manufacturing Process Optimization project?
Show their skills and relevant document references with storage paths.
```

**Prompt 3 – Confidence analysis:**
```
Find all parsed documents for the R&D department where documentConfidence is below 0.7.
Include documentId, employeeId, cosmosDbRecordId, and storageRef.relativePath for each.
```

**Prompt 4 – Organizational hierarchy:**
```
Who are the direct reports of the VP of Engineering?
List their roles, departments, and active project assignments.
```

**Prompt 5 – Operational troubleshooting:**
```
Identify employees who have assets uploaded to blob storage but no corresponding parse record in Cosmos DB.
Include their employeeId, asset file names, and expected storage paths.
```

### Expected Response Format

All responses should include:
```json
{
  "answer": "...",
  "citations": [
    {
      "documentId": "DOC-EMP001-02",
      "cosmosDbRecordId": "parse-EMP001-02",
      "storageRef": {
        "container": "employee-knowledge-raw",
        "relativePath": "employees/EMP001/AST-EMP001-02.pdf"
      },
      "documentConfidence": 0.92
    }
  ]
}
```

---

## Act 6 – Azure Monitor & SRE Dashboard

**Duration:** 5 minutes  
**Goal:** Show the live monitoring posture.

### Steps

1. **Open** Azure portal → **Monitor** → **Alerts** → filter by subscription.
2. **Show** the 6 active alert rules:
   - Storage availability
   - Cosmos DB 5xx errors
   - Cosmos DB 429 throttling
   - UI App Service HTTP 5xx
   - UI App Service response time
   - Low parse confidence (scheduled query)

3. **Click** one alert rule (e.g., `alert-ui-http5xx-fabriciq`):
   > "This alert fires when the UI app returns more than 5 HTTP 5xx errors in a 5-minute window. It's Severity 1 with a 15-minute response SLA."

4. **Show** the Action Group `ag-fabriciq-sre`:
   > "All six alerts route to this shared SRE action group, which notifies the email DL and calls the Logic App HTTP trigger."

5. **Open** Log Analytics workspace → **Logs** → run a sample query:
   ```kql
   AppServiceHTTPLogs
   | where ScStatus >= 500
   | summarize ErrorCount = count() by bin(TimeGenerated, 5m)
   | order by TimeGenerated desc
   | take 20
   ```
   > "All App Service HTTP logs flow here. The scheduled query alert runs this type of analysis automatically every 15 minutes."

6. **Navigate** to **Diagnostic Settings** on the Storage Account – show the three active categories.

---

## Act 7 – Incident Response Flow

**Duration:** 5 minutes  
**Goal:** Demonstrate the automated incident response pipeline.

### Steps

1. **Open** `logic-fabriciq-incident-response` in the Azure portal → **Logic app designer**.

2. **Walk through** the workflow steps:
   - **HTTP Trigger**: "When an Azure Monitor alert fires"
   - **Action 1**: `Log_Incident_to_Cosmos` – writes to Cosmos DB `Incidents` container
   - **Action 2**: `Notify_SRE_Teams_Channel` – sends a MessageCard to the Teams SRE channel

3. **Open** `docs/incident-response-plan.md`:
   > "The incident response plan defines severity levels, triage steps, and remediation runbooks for each of the 6 alert types. For example, a Cosmos DB 5xx alert triggers this playbook..."

4. **Navigate** to Cosmos DB → `Incidents` container → show the schema:
   > "Every alert that fires creates an incident record here with alertRule, severity, firedAt, and status. This gives us a full incident history for trend analysis and post-incident review."

5. **Show** the escalation matrix from the incident response plan:
   > "Sev 1 alerts page the on-call engineer immediately. Sev 2 has a 30-minute SLA. All escalations go through the Teams SRE channel."

---

## Act 8 – Teams & Copilot Agent Packaging

**Duration:** 3 minutes  
**Goal:** Show how to publish the agent to Teams and Copilot.

### Steps

1. **Open** `fabric/agents/employee_knowledge_agent.json`:
   > "The agent definition includes the agent name, description, capabilities, and prompt configuration."

2. **Explain** the packaging steps:
   ```
   1. Export agent JSON → zip as FabricEmployeeKnowledgeAgent.zip
   2. Open Teams Developer Portal: https://dev.teams.microsoft.com
   3. Import zip → validate → configure data permissions
   4. Publish to Teams and Microsoft Copilot
   ```

3. **Open** Teams Developer Portal (Tab) → show the import flow.

4. **Close** with the value statement:
   > "Once published, any employee can ask 'What are the skills gaps on Project X?' or 'Show me all R&D documents with low parse confidence' directly in Teams or Microsoft 365 Copilot – with full citations back to source."

---

## Q&A Talking Points

**Q: How does this scale beyond 100 employees?**  
A: The config-driven architecture, private endpoints, and Cosmos DB partition key (`/employeeId`) are designed to scale to tens of thousands of employees. Fabric pipelines can be scheduled for incremental ingestion.

**Q: How are credentials managed?**  
A: All services use system-assigned managed identities. No secrets are embedded in code or config. RBAC is least-privilege per service.

**Q: What if Document Intelligence confidence is too low?**  
A: Low-confidence records (< 0.5) trigger the scheduled query alert (`sqr-low-confidence-docs-fabriciq`), which routes to the SRE team for review. Records can be re-submitted after tuning the model.

**Q: Can this be connected to a real employee directory?**  
A: Yes. The ingestion pipeline can be adapted to pull from Microsoft Graph (Entra ID) for real employee data instead of the synthetic dataset.

**Q: What does the Logic App cost to run?**  
A: Logic App consumption tier pricing is per-execution. At typical alert volumes (a few per day), the cost is negligible – often under $1/month.

**Q: How quickly can this be deployed in a new environment?**  
A: A fresh environment can be deployed in under 30 minutes using the provided Terraform configuration and GitHub workflows.

---

## Abbreviated Demo Path (15 min)

For time-constrained demonstrations, follow this reduced path:

| Step | Duration | Focus |
|------|----------|-------|
| Act 1 – Architecture overview | 3 min | Architecture SVG + key talking points |
| Act 4a/4d – UI: Data Sources + Prompts | 4 min | Employee search + document viewer + agent prompt copy |
| Act 5 – Live Data Agent prompts | 3 min | 2 sample prompts (confidence + skill lookup) |
| Act 6 – Azure Monitor dashboard | 3 min | Alert rules + action group |
| Act 7 – Incident response (summary) | 2 min | Logic App flow + IRP document reference |

**Skip** Acts 2, 3, 4b/c/e, and 8 for the abbreviated path.
