# Fabric Deployment Guide

This guide covers everything you need to configure before running the deployment workflows. All Fabric workspace creation, semantic model provisioning, and pipeline setup is handled automatically by the `deploy.yml` GitHub Actions workflow via the Fabric REST API — no Fabric portal steps are required.

---

## Prerequisites

| Tool | Minimum version | Notes |
|---|---|---|
| Terraform | 1.6.0+ | Used by CI and deploy workflows |
| Azure CLI | 2.55.0+ | Used by deploy workflow and local scripts |
| Python | 3.9+ | Used by data-prep script |
| Node.js | 20 LTS | Used by UI build step |

---

## Step 1 — Configure Terraform variables

Edit `config/terraform.tfvars.json` with your environment values. All fields are required unless marked optional.

```json
{
  "resource_group_name":            "your-resource-group",
  "storage_account_name":           "globally-unique-storage-name",
  "raw_container_name":             "employee-knowledge-raw",
  "processed_container_name":       "employee-knowledge-processed",
  "cosmos_account_name":            "globally-unique-cosmos-name",
  "cosmos_database_name":           "EmployeeKnowledgeGraph",
  "cosmos_container_name":          "EmployeeDocumentParsing",
  "ui_app_service_name":            "your-ui-app-name",
  "api_app_service_name":           "your-api-app-name",
  "app_service_plan_name":          "plan-fabriciq-b3",
  "app_service_plan_sku":           "B3",
  "app_service_plan_location":      "westus2",
  "fabric_capacity_id":             "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Fabric/capacities/<NAME>",
  "fabric_workspace_display_name":  "Fabric IQ – Employee Knowledge",
  "existing_log_analytics_workspace_name": "",
  "sre_alert_email":                "sre@yourcompany.com",
  "sre_webhook_url":                "https://your-teams-webhook-url",
  "tags": {
    "project": "fabric-iq-employee-knowledge",
    "environment": "demo",
    "owner": "your-alias"
  }
}
```

**Key fields:**

| Field | How to obtain |
|---|---|
| `resource_group_name` | Must already exist in your Azure subscription |
| `storage_account_name` | Must be globally unique (3–24 lowercase alphanumeric chars) |
| `cosmos_account_name` | Must be globally unique (3–44 lowercase chars) |
| `fabric_capacity_id` | Azure portal → Microsoft Fabric → Capacities → select capacity → copy resource ID; or run `az resource list --resource-type Microsoft.Fabric/capacities -o table` |
| `sre_alert_email` | Email that receives Azure Monitor alert notifications |
| `sre_webhook_url` | Teams incoming webhook or similar (leave empty to skip notifications) |

---

## Step 2 — Configure Fabric and Azure endpoint IDs

Edit `config/endpoints.json` with the GUIDs for your Fabric resources. The `deploy-fabric-components` job creates the workspace and returns IDs in its log output — copy them here after the first run, then re-push so subsequent runs use the correct IDs.

```json
{
  "microsoftFabric": {
    "workspaceId":    "<fabric-workspace-guid>",
    "ontologyId":     "<ontology-guid>",
    "lakehouseId":    "<lakehouse-guid>",
    "capacityId":     "<capacity-short-guid>",
    "pipelineId":     "<pipeline-guid>",
    "semanticModelId":"<semantic-model-guid>",
    "dataAgentId":    "<data-agent-guid>",
    "tenantId":       "<azure-ad-tenant-guid>"
  },
  "hosting": {
    "uiPublicUrl": "https://<ui_app_service_name>.azurewebsites.net",
    "apiUrl":      "https://<api_app_service_name>.azurewebsites.net"
  }
}
```

---

## Step 3 — Configure Azure hosting resource names

Edit `config/azure-hosting-resources.json` so the deploy workflow targets the correct subscription and app names.

```json
{
  "subscriptionId": "<your-azure-subscription-id>",
  "resourceGroup":  "your-resource-group",
  "hosting": {
    "apiWebApp": { "name": "your-api-app-name" },
    "uiWebApp":  { "name": "your-ui-app-name" }
  },
  "fabric": {
    "capacityId": "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Fabric/capacities/<NAME>"
  }
}
```

---

## Step 4 — Set GitHub repository secrets

Navigate to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret | Value |
|---|---|
| `AZURE_CLIENT_ID` | Client ID of the service principal or managed identity |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID (overrides the value in `azure-hosting-resources.json`) |
| `AZURE_CREDENTIALS` | Full service principal JSON — only needed if not using OIDC |
| `AZURE_STORAGE_ACCOUNT` | Storage account name for blob upload steps |

**Recommended: OIDC authentication**

Create a federated credential on your service principal so no secret rotation is needed:

```bash
az ad app federated-credential create \
  --id <APP_OBJECT_ID> \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<OWNER>/<REPO>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

Then set only `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` (no `AZURE_CREDENTIALS` needed).

---

## Step 5 — (Optional) Pre-generate data exports

Run the data-prep script locally if you want to validate the source data before deploying:

```bash
pip install pandas
python scripts/populate_fabric_complete.py
```

This regenerates:
- `fabric/ontology/fabric_iq_ontology_complete.json`
- `fabric/pipelines/employee_knowledge_pipeline_complete.json`
- `data/exports/parquet/*.csv` (4 CSV files)

The deploy workflow also runs equivalent logic automatically, so this step is optional.

---

## What the deploy workflow creates automatically

The `deploy-fabric-components` job in `deploy.yml` handles all Fabric provisioning via the Fabric REST API (`https://api.fabric.microsoft.com/v1`):

| Action | How |
|---|---|
| Resume Fabric capacity | `az rest POST .../resume` |
| Create / verify workspace | `GET /workspaces/{id}` — warns if not found; create with `POST /workspaces` |
| Create semantic model | `POST /workspaces/{id}/semanticModels` |
| Create data pipeline | `POST /workspaces/{id}/dataPipelines` |
| Upload data to blob | `az storage blob upload` for each JSON file in `data/` |

The `terraform-apply` job creates all Azure infrastructure:

| Resource | Terraform file |
|---|---|
| Storage account + containers | `terraform/main.tf` |
| Cosmos DB account, database, containers | `terraform/main.tf` |
| App Service plan (B3 Linux) | `terraform/main.tf` |
| UI and API web apps | `terraform/main.tf` |
| Log Analytics workspace | `terraform/monitors.tf` |
| Diagnostic settings | `terraform/monitors.tf` |
| Monitor metric alerts | `terraform/monitors.tf` |
| Logic App (incident response) | `terraform/monitors.tf` |
