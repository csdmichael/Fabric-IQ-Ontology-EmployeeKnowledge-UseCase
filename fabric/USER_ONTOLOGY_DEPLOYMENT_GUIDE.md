# Fabric Ontology Deployment Guide

**Date**: May 10, 2026  
**Status**: Using User-Created Fabric Ontology (Primary Source of Truth)  
**User Ontology**: https://app.powerbi.com/groups/38362838-0531-4215-89af-a8a79221b545/ontologies/2902d438-68bc-4760-ad6a-bef9208c14b2

---

## Executive Summary

This guide explains how to deploy the Fabric Employee Knowledge system using **your custom Fabric ontology** as the single source of truth. The system is production-ready with:

- ✅ **API**: Running on Azure App Service (Python FastAPI)
- ✅ **UI**: Enhanced with geographical maps, trend analysis, comparative reports, and advanced visualizations
- ✅ **Data**: 1,020 employee records ready to load
- ✅ **Infrastructure**: Azure deployment complete (resource group, storage, semantic model)

---

## Phase 1: Extract & Align Ontology

### Step 1.1: Review Your Fabric Ontology
1. Open your ontology at: https://app.powerbi.com/groups/38362838-0531-4215-89af-a8a79221b545/ontologies/2902d438-68bc-4760-ad6a-bef9208c14b2
2. Document the entity definitions:
   - **Entities**: Names, properties, data types
   - **Relationships**: Connections between entities
   - **Hierarchies**: Any organizational hierarchies defined
   - **Key Fields**: Primary/foreign keys

### Step 1.2: Compare with Local Config
Current local ontology (for reference):
```json
{
  "entities": [
    "Employee", "Manager", "Department", 
    "Document", "Email", "OneNote", 
    "Project", "Skill"
  ],
  "relationships": [
    "Employee_REPORTS_TO_Manager",
    "Employee_BELONGS_TO_Department",
    "Employee_OWNS_Document",
    "Employee_WRITES_Email",
    "Employee_MAINTAINS_OneNote",
    "Employee_CONTRIBUTES_TO_Project",
    "Employee_HAS_Skill"
  ]
}
```

### Step 1.3: Update Local Config if Needed
If your Fabric ontology differs:
- Edit `config/ontology-config.json` to match your entity/relationship structure
- Update `fabric/ontology/fabric_iq_ontology.json` with property mappings

---

## Phase 2: Create OneLake Tables

### Step 2.1: Open Your Lakehouse
1. Go to Workspace: **38362838-0531-4215-89af-a8a79221b545**
2. Open Lakehouse: **d11b209f-c774-481e-adcb-79920a94fd20**
3. Click "New table" in the Tables section

### Step 2.2: Create Tables from Your Ontology
For each entity in your ontology, create a table:

**Example: Employee Table**
```sql
-- Based on your ontology entity definition
CREATE TABLE Employee (
    employeeId VARCHAR(50) PRIMARY KEY,
    displayName VARCHAR(255),
    email VARCHAR(255),
    department VARCHAR(100),
    role VARCHAR(100),
    location VARCHAR(100),
    skills VARCHAR(500),
    hireDate DATE
)
```

**Repeat for**: Department, Manager, Document, Email, Skill, Project (per your ontology)

### Step 2.3: Define Relationships
In the Lakehouse, define relationships per your ontology:
- Employee → Manager (foreign key)
- Employee → Department (foreign key)
- Employee → Skills (many-to-many)
- Employee → Projects (many-to-many)

---

## Phase 3: Load Data to OneLake

### Step 3.1: Prepare Data Files
Data files are ready at:
- `data/exports/parquet/employees.csv` (100 records)
- `data/exports/parquet/contributions.csv` (100 records)
- `data/exports/parquet/digital_assets.csv` (800 records)
- `data/exports/parquet/projects.csv` (20 records)

### Step 3.2: Load Data via Dataflow or Power BI
**Option A: Dataflow (Recommended)**
1. In Lakehouse, create a new Dataflow
2. Select "Text/CSV" source
3. Upload CSV files from `data/exports/parquet/`
4. Configure column mappings to match your ontology schema
5. Load to OneLake tables

**Option B: Power BI Desktop**
1. Open Power BI Desktop
2. Get Data → Text/CSV
3. Point to `data/exports/parquet/` folder
4. Configure transformations
5. Load to Lakehouse

### Step 3.3: Validate Data
```sql
-- Verify record counts in Lakehouse
SELECT COUNT(*) as employee_count FROM Employee;
SELECT COUNT(*) as contribution_count FROM Contribution;
-- Expected: 100 employees, 100 contributions, 800 assets, 20 projects
```

---

## Phase 4: Configure Semantic Model

### Step 4.1: Open Semantic Model
1. Go to Workspace: **38362838-0531-4215-89af-a8a79221b545**
2. Open Semantic Model: **21e0a7be-1e7d-4110-8faa-d835f81c6559**

### Step 4.2: Create Model Relationships
Per your ontology:
1. **Employee ← → Department** (one-to-many)
2. **Employee ← → Manager** (self-referencing one-to-many)
3. **Employee ← → Skills** (many-to-many)
4. **Employee ← → Projects** (many-to-many)

### Step 4.3: Create Measures
```dax
-- Total Employees
Total Employees = COUNTA(Employee[employeeId])

-- Average Contribution Score
Average Employee Score = AVERAGE(Contribution[contributionScore])

-- Skills per Employee
Avg Skills per Emp = AVERAGE(Contribution[skillCount])

-- Projects per Employee
Avg Projects per Emp = AVERAGE(Contribution[projectCount])

-- Digital Assets Count
Total Assets = COUNTA(DigitalAsset[assetId])
```

---

## Phase 5: Create Power BI Reports

### Step 5.1: Create Report: Employee Skills Dashboard
**Pages:**
1. **Overview**
   - Total Employees (KPI card)
   - Average Contribution Score (KPI card)
   - Skills Matrix (table: Name, Department, Skills)
   - Contribution by Tier (bar chart)

2. **Geographical Analytics** (NEW)
   - Employee Distribution Map (map visualization with locations)
   - Location Heatmap (count by city)
   - Top Locations KPI

3. **Trend Analysis** (NEW)
   - Contribution Score Trend (line chart)
   - Skill Growth (multi-line chart)
   - Project Velocity (bar chart)

4. **Comparative Reports** (NEW)
   - Department Comparison (bar chart)
   - Tier Comparison (stacked bar)
   - Top Performers Table

### Step 5.2: Create Report: Project Analytics
- Project Overview
- Projects per Department
- Project Duration Trends
- Asset Distribution by Project

### Step 5.3: Pin Visualizations to Dashboard
1. Create Power BI Dashboard: "Employee Knowledge Hub"
2. Pin key visualizations from reports
3. Set auto-refresh schedule (if needed)

---

## Phase 6: Update Application Configuration

### Step 6.1: Verify API Configuration
The API is already configured with your Fabric workspace IDs:
```bash
curl https://fabric-iq-emp-knowledge-api.azurewebsites.net/api/config/endpoints
```

Expected response includes:
```json
{
  "microsoftFabric": {
    "workspaceId": "38362838-0531-4215-89af-a8a79221b545",
    "ontologyId": "2902d438-68bc-4760-ad6a-bef9208c14b2",
    "lakehouseId": "d11b209f-c774-481e-adcb-79920a94fd20",
    "semanticModelId": "21e0a7be-1e7d-4110-8faa-d835f81c6559"
  }
}
```

### Step 6.2: Verify UI Enhancements
The UI is now deployed with new pages:
- **Geographical Analytics**: Map-based employee distribution
- **Trend Analysis**: Time-series visualizations
- **Comparative Reports**: Department/tier/location comparisons
- **Advanced Visualizations**: Scatter plots, bubble charts, heatmaps

Access at: https://fabric-iq-emp-knowledge-ui.azurewebsites.net

---

## Phase 7: Clean Up Redundant Components

### What's Removed
- ~~`fabric/ontology/fabric_iq_ontology_complete.json`~~ (auto-generated, superseded)
- ~~`fabric/pipelines/employee_knowledge_pipeline_complete.json`~~ (auto-generated duplicate)
- Auto-generated report configs that conflict with user ontology

### What's Kept
- `config/ontology-config.json` - Local reference to user ontology structure
- `config/endpoints.json` - Fabric workspace & ontology IDs
- `fabric/ontology/fabric_iq_ontology.json` - Working copy aligned with user design
- `fabric/pipelines/employee_knowledge_pipeline.json` - Data pipeline

### Principle
**User ontology is the single source of truth.** All local configs reference and align with it.

---

## Deployment Checklist

- [ ] Extract user ontology structure (Step 1)
- [ ] Create OneLake tables per ontology (Step 2)
- [ ] Load 1,020 employee records to OneLake (Step 3)
- [ ] Configure semantic model relationships (Step 4)
- [ ] Create Power BI reports with visualizations (Step 5)
- [ ] Verify API endpoints are responding (Step 6)
- [ ] Test UI pages: Geographical Analytics, Trends, Comparisons (Step 6)
- [ ] Publish Power BI app to workspace (Step 5)
- [ ] Remove redundant auto-generated files (Step 7)
- [ ] Validate end-to-end data flow (API → UI → Reports)

---

## API Endpoints (Verified & Running)

```bash
# Health Check
GET https://fabric-iq-emp-knowledge-api.azurewebsites.net/health
→ Status 200

# Configuration
GET https://fabric-iq-emp-knowledge-api.azurewebsites.net/api/config/endpoints
→ Fabric workspace IDs, ontology reference

# Data Endpoints
GET https://fabric-iq-emp-knowledge-api.azurewebsites.net/api/employees (100 records)
GET https://fabric-iq-emp-knowledge-api.azurewebsites.net/api/projects (20 records)
GET https://fabric-iq-emp-knowledge-api.azurewebsites.net/api/summary (1,020 records total)
```

---

## UI Pages (Enhanced - All Deployed)

- **Dashboard**: KPI summary, workspace info
- **Employees**: Searchable employee directory
- **Projects**: Project listing with details
- **Org Structure**: Organization hierarchy
- **Geographical Analytics**: Map + location heatmap (NEW)
- **Trend Analysis**: Contribution, skill, project trends (NEW)
- **Comparative Reports**: Department/tier comparisons (NEW)
- **Advanced Visualizations**: Scatter, bubble, heatmap charts (NEW)
- **Power BI Reports**: Link to Fabric workspace
- **Agent Prompts**: 30 sample prompts (20 employee + 10 SRE)
- **Config**: Endpoints and workspace info

---

## Support & Troubleshooting

**Q: How do I access the Fabric workspace?**
A: Go to https://app.powerbi.com/groups/38362838-0531-4215-89af-a8a79221b545

**Q: How do I view the ontology I created?**
A: Open https://app.powerbi.com/groups/38362838-0531-4215-89af-a8a79221b545/ontologies/2902d438-68bc-4760-ad6a-bef9208c14b2

**Q: What if my ontology structure is different from the local config?**
A: Update `config/ontology-config.json` and `fabric/ontology/fabric_iq_ontology.json` to match. The local config is a reference guide only; your Fabric ontology is the source of truth.

**Q: How do I load data?**
A: Use Fabric Dataflow or Power BI Desktop to map CSV files to your OneLake tables. Data files are at `data/exports/parquet/`.

---

## Next Steps

1. ✅ Infrastructure & API: Complete and running
2. ✅ UI Enhanced: Geographical maps, trend charts, comparisons deployed
3. ⏳ **[YOUR ACTION]** Extract ontology structure from Power BI
4. ⏳ **[YOUR ACTION]** Create OneLake tables per your ontology
5. ⏳ **[YOUR ACTION]** Load 1,020 employee records
6. ⏳ **[YOUR ACTION]** Create Power BI reports and dashboard
7. ⏳ **[YOUR ACTION]** Publish Power BI app

All code, scripts, and configuration are in the GitHub repository and ready for deployment.
