# Fabric IQ Employee Knowledge API

This API serves repository JSON artifacts through config-driven read endpoints.

## Run locally

```bash
python api/server.py
```

Default address: `http://localhost:8080`

## Endpoints

### System

- `GET /health` or `GET /api/health` — Health check
- `GET /docs` or `GET /swagger` — Swagger UI
- `GET /swagger.json` — OpenAPI spec
- `GET /api/summary` — Record counts for all entities (employees, documents, Graph items, AI Search index size)

### Configuration

- `GET /api/config/endpoints` — Returns `config/endpoints.json` (Fabric workspace IDs, Azure URLs)
- `GET /api/config/service-config` — Returns `config/service-config.json` (Document Intelligence, Graph, AI Search, OpenAI, hosting URLs)

### Employee Data

- `GET /api/employees` — All 100 employee records
- `GET /api/contributions` — All 100 contribution records
- `GET /api/digital-assets` — All 800 digital asset records
- `GET /api/projects` — All 20 project records
- `GET /api/org-hierarchy` — Organisation hierarchy tree
- `GET /api/emails` — Sample email activity
- `GET /api/powerbi-reports` — Power BI report metadata
- `GET /api/parsed-documents` — Parsed document metadata stored in Cosmos DB

### AI & Data Services

- `GET /api/document-intelligence` — Azure AI Document Intelligence extraction results (PDF, PPTX, XLSX, DOCX) with tables, key-value pairs, and paragraphs
- `GET /api/graph-data` — Microsoft Graph sample data (M365 users, SharePoint/OneDrive files, Outlook emails, Teams activity)
- `GET /api/ai-search` — Azure AI Search index stats, semantic query results, facets, and indexer configuration

## Optional filters

List endpoints support optional query filters:

- `department=<name>` (where the payload has a `department` field)
- `employeeId=<id>` (where the payload has an `employeeId` field)

## Response format

All endpoints return `application/json` with CORS headers. All errors return a JSON body with an `error` field.

```json
{ "error": "Not found", "path": "/api/unknown" }
```
