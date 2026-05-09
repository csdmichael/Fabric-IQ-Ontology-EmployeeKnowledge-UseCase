# Fabric IQ Employee Knowledge – Incident Response Plan

> **Owner:** Michael Yaacoub – Microsoft  
> **Last Updated:** 2026-05  
> **Scope:** All monitored resources in the `ai-myaacoub` resource group that support the Fabric IQ Employee Knowledge demo.

---

## Table of Contents
- [Severity Definitions](#severity-definitions)
- [Monitored Resources](#monitored-resources)
- [Alert Catalog](#alert-catalog)
- [Automated Response Flow](#automated-response-flow)
- [Playbooks](#playbooks)
  - [P1 – Storage Availability Degradation](#p1--storage-availability-degradation)
  - [P2 – Cosmos DB Server Errors (5xx)](#p2--cosmos-db-server-errors-5xx)
  - [P3 – Cosmos DB Request Throttling (429)](#p3--cosmos-db-request-throttling-429)
  - [P4 – UI App Service HTTP 5xx Errors](#p4--ui-app-service-http-5xx-errors)
  - [P5 – UI App Service High Response Time](#p5--ui-app-service-high-response-time)
  - [P6 – Low Document Parse Confidence](#p6--low-document-parse-confidence)
- [Escalation Matrix](#escalation-matrix)
- [Post-Incident Review](#post-incident-review)

---

## Severity Definitions

| Severity | Label    | Response SLA | Description |
|----------|----------|-------------|-------------|
| Sev 1    | Critical | 15 min      | Service outage or complete data loss risk. Immediate page to on-call. |
| Sev 2    | High     | 30 min      | Significant degradation affecting users. Escalate within 30 min. |
| Sev 3    | Medium   | 2 hours     | Partial degradation; workaround available. Escalate within 2 hours. |
| Sev 4    | Low      | Next business day | Minor issue or informational. Tracked in backlog. |

---

## Monitored Resources

| Resource | Type | Alert Scope |
|----------|------|-------------|
| `stfabriciqdemodata01` | Azure Storage Account | Availability, Transaction errors |
| `cosmos-fabriciq-demo-01` | Cosmos DB Account | 5xx errors, 429 throttling, RU consumption |
| `fabric-iq-emp-knowledge-ui` | App Service (Linux) | HTTP 5xx count, Average response time |
| Log Analytics Workspace | `law-fabriciq-emp-knowledge` | Scheduled query – low confidence parse records |

---

## Alert Catalog

| Alert Name | Resource | Metric / Query | Threshold | Severity |
|-----------|---------|---------------|-----------|----------|
| `alert-storage-availability-fabriciq` | Storage Account | `Availability` avg | < 99% over 15 min | Sev 1 |
| `alert-cosmos-server-errors-fabriciq` | Cosmos DB | `TotalRequests` (5xx) count | > 5 in 5 min | Sev 1 |
| `alert-cosmos-ru-throttle-fabriciq` | Cosmos DB | `TotalRequests` (429) count | > 10 in 5 min | Sev 2 |
| `alert-ui-http5xx-fabriciq` | App Service | `Http5xx` count | > 5 in 5 min | Sev 1 |
| `alert-ui-response-time-fabriciq` | App Service | `AverageResponseTime` avg | > 5s over 15 min | Sev 2 |
| `sqr-low-confidence-docs-fabriciq` | Log Analytics | Cosmos parse confidence < 0.5 | > 10 docs in 1 hr | Sev 2 |

All alerts are routed to the **SRE Action Group** (`ag-fabriciq-sre`) which notifies:
- SRE email distribution list
- HTTP trigger on the incident response Logic App (`logic-fabriciq-incident-response`)
- Teams SRE channel (via Logic App)

---

## Automated Response Flow

```
Azure Monitor Alert fires
        │
        ▼
Action Group: ag-fabriciq-sre
  ├─ Email → SRE DL
  └─ Webhook → logic-fabriciq-incident-response (HTTP Trigger)
                    │
                    ├─ Log Incident to Cosmos DB (Incidents container)
                    └─ Notify Teams SRE Channel (MessageCard)
```

The Logic App is deployed via Terraform (`terraform/monitors.tf`).  
After first `terraform apply`, copy `incident_response_logic_app_trigger_url` output value
and set it as the `sre_webhook_url` tfvar (or action group webhook) for end-to-end routing.

---

## Playbooks

### P1 – Storage Availability Degradation

**Alert:** `alert-storage-availability-fabriciq`  
**Severity:** Sev 1

#### Triage Steps
1. Open the Azure portal → `stfabriciqdemodata01` → **Monitoring** → **Metrics**.
2. Check `Availability` metric for the affected blob service tier.
3. Verify no active Azure platform incidents: <https://status.azure.com>.
4. Check storage account **Activity Log** for recent configuration changes or policy denials.

#### Remediation
- If caused by network issue: verify private endpoint (`pe-blob-westus2`) is healthy.
- If caused by access denied: check managed identity RBAC on Storage Blob Data Contributor.
- If platform issue: open Azure Support ticket and communicate status to stakeholders.
- Re-trigger failed Fabric pipeline activities once storage is restored.

#### Escalation
- 15 min without resolution → escalate to Sev 1 on-call engineer.

---

### P2 – Cosmos DB Server Errors (5xx)

**Alert:** `alert-cosmos-server-errors-fabriciq`  
**Severity:** Sev 1

#### Triage Steps
1. Open Azure portal → `cosmos-fabriciq-demo-01` → **Insights** → **Requests** tab.
2. Filter by `StatusCode = 500` or `503` to identify affected partitions.
3. Review `DataPlaneRequests` logs in Log Analytics for the request payload patterns.
4. Check for high RU consumption correlated with the error window.

#### Remediation
- Retry policy: Fabric pipelines have built-in retry (3 attempts, exponential back-off).
- If container partition pressure: evaluate partition key design (`/employeeId`).
- If service degradation: check Cosmos DB SLA breach and open Azure Support ticket.
- Restart affected Fabric pipeline activity after Cosmos returns healthy.

#### Escalation
- 15 min without resolution → escalate to data engineering lead.

---

### P3 – Cosmos DB Request Throttling (429)

**Alert:** `alert-cosmos-ru-throttle-fabriciq`  
**Severity:** Sev 2

#### Triage Steps
1. Open `cosmos-fabriciq-demo-01` → **Insights** → **Requests** → filter `StatusCode = 429`.
2. Identify which container and time window has the spike.
3. Review `PartitionKeyStatistics` logs for hot partition detection.

#### Remediation
- Short term: increase provisioned RU/s on `EmployeeDocumentParsing` container temporarily.
- Medium term: review employee upload batch sizes and pipeline concurrency settings.
- Long term: evaluate autoscale RU/s configuration for the Cosmos container.

#### Escalation
- 30 min without resolution → escalate to data engineering lead.

---

### P4 – UI App Service HTTP 5xx Errors

**Alert:** `alert-ui-http5xx-fabriciq`  
**Severity:** Sev 1

#### Triage Steps
1. Open `fabric-iq-emp-knowledge-ui` → **Log stream** → inspect recent error traces.
2. Check **AppServiceHTTPLogs** in Log Analytics for 5xx URL paths.
3. Verify the app deployment (`WEBSITE_RUN_FROM_PACKAGE`) is intact.
4. Check `AppServiceConsoleLogs` for Node.js crash or unhandled rejection.

#### Remediation
- Restart the App Service if it is in a degraded state.
- Roll back to previous deployment package if a bad deploy caused the regression.
- Verify API backend (`foundry-privatevnet-api`) is reachable over the private VNet route.
- Check APIM gateway (`ai-gateway-apim-poc-my`) health if API calls are failing.

#### Escalation
- 15 min without resolution → escalate to frontend/SRE lead.

---

### P5 – UI App Service High Response Time

**Alert:** `alert-ui-response-time-fabriciq`  
**Severity:** Sev 2

#### Triage Steps
1. Open `fabric-iq-emp-knowledge-ui` → **Performance** → **Response time** metric.
2. Identify which routes are slow using `AppServiceHTTPLogs`.
3. Check if slow responses correlate with Cosmos DB or APIM latency spikes.
4. Inspect App Service **Memory** and **CPU** metrics for resource contention.

#### Remediation
- If memory/CPU bound: scale up or out the App Service Plan (`plan-taxforms`).
- If backend latency: optimize Cosmos DB queries or add index policies.
- If cold start: enable **Always On** on the App Service (upgrade from B1 SKU if needed).

#### Escalation
- 30 min without resolution → escalate to full-stack SRE team.

---

### P6 – Low Document Parse Confidence

**Alert:** `sqr-low-confidence-docs-fabriciq`  
**Severity:** Sev 2

#### Triage Steps
1. Query Cosmos DB `EmployeeDocumentParsing` container for records with `documentConfidence < 0.5`.
2. Identify which employee IDs and asset types are affected.
3. Review the Document Intelligence service endpoint configuration in `config/endpoints.json`.
4. Check Document Intelligence resource quota and throttling logs.

#### Remediation
- Re-submit affected employee assets through the Fabric ingestion pipeline.
- Review Document Intelligence model version for breaking changes.
- Flag low-confidence records for manual review using the governance dashboard.
- Adjust confidence threshold alerts if baseline shifts after model update.

#### Escalation
- 2 hours without resolution → escalate to data engineering lead.

---

## Escalation Matrix

| Role | Contact Method | Escalation Condition |
|------|---------------|---------------------|
| SRE On-Call | Teams SRE Channel + Email DL | Any Sev 1 alert, or Sev 2 unresolved in 30 min |
| Data Engineering Lead | Teams DM + Email | Cosmos DB or Document Intelligence issues |
| Frontend/Full-Stack Lead | Teams DM + Email | App Service or UI issues |
| Microsoft Azure Support | <https://portal.azure.com/#blade/Microsoft_Azure_Support> | Platform-level failures |

---

## Post-Incident Review

After any Sev 1 or Sev 2 incident:

1. **Timeline** – Document the timeline of events from first alert to resolution.
2. **Root cause** – Identify the root cause (configuration, code, platform, or data issue).
3. **Impact** – Quantify user impact (downtime, data affected, confidence degradation).
4. **Action items** – List follow-up tasks with owners and due dates.
5. **Process improvements** – Update playbooks, thresholds, or automation as needed.
6. **Record** – Log the incident in the Cosmos DB `Incidents` container for trend analysis.

Post-incident review template is available in `docs/incident-review-template.md` (create as needed).
