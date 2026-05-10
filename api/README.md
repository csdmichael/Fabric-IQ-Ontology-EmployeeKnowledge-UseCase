# Fabric IQ Employee Knowledge API

This API serves repository JSON artifacts through config-driven read endpoints.

## Run locally

```bash
python api/server.py
```

Default address: `http://localhost:8080`

## Endpoints

- `GET /health` or `GET /api/health`
- `GET /api/summary`
- `GET /api/config/endpoints`
- `GET /api/employees`
- `GET /api/digital-assets`
- `GET /api/emails`
- `GET /api/org-hierarchy`
- `GET /api/projects`
- `GET /api/contributions`
- `GET /api/powerbi-reports`
- `GET /api/parsed-documents`

## Optional filters

List endpoints support optional query filters:

- `department=<name>` (where the payload has a `department` field)
- `employeeId=<id>` (where the payload has an `employeeId` field)
