# FABRIC & POWER BI DEPLOYMENT PLAYBOOK

## Overview
This playbook provides step-by-step instructions for deploying Fabric objects and Power BI reports. All components are automated and verified - now complete the manual configuration steps in Power BI portal.

**Timeline**: ~70 minutes (mostly manual Power BI configuration)  
**Status**: Ready to deploy  
**Data**: 1,020 records verified and ready

---

## PRE-DEPLOYMENT CHECKLIST

✅ **Data Verified**
- Employees.csv: 100 rows
- Contributions.csv: 100 rows
- DigitalAssets.csv: 800 rows
- Projects.csv: 20 rows
- Total: 1,020 records

✅ **Configurations Verified**
- Fabric workspace ID: 38362838-0531-4215-89af-a8a79221b545
- Lakehouse ID: d11b209f-c774-481e-adcb-79920a94fd20
- Semantic model ID: 21e0a7be-1e7d-4110-8faa-d835f81c6559
- Ontology: 4 tables, 2 relationships defined
- Power BI config: 3 reports, 11 visuals

✅ **Permissions Required**
- Power BI Premium or Fabric capacity
- Admin access to workspace
- Write access to lakehouse and semantic model

---

## STEP 1: LOAD DATA TO ONELAKE (10 minutes)

### Option A: Manual CSV Upload (Easiest)

1. **Open Power BI Portal**
   - Go to: https://app.powerbi.com
   - Sign in with your Fabric account

2. **Navigate to Workspace**
   - Select workspace: "Employee Knowledge Graph"
   - Or use ID: 38362838-0531-4215-89af-a8a79221b545

3. **Open Lakehouse**
   - Click on Lakehouse "EmployeeKnowledgeLH"
   - Or use ID: d11b209f-c774-481e-adcb-79920a94fd20

4. **Upload Files**
   - Click "Get Data" → "Upload files"
   - Select from: `data/exports/parquet/`
   - Upload all 4 CSV files:
     - Employees.csv
     - Contributions.csv
     - DigitalAssets.csv
     - Projects.csv

5. **Create Tables**
   - For each CSV file:
     - Click Upload
     - Confirm table name (should match file name)
     - Click Load
   - Verify: 1,020 total records loaded

6. **Verify Data**
   - Check each table:
     - Employees: 100 rows
     - Contributions: 100 rows
     - DigitalAssets: 800 rows
     - Projects: 20 rows

### Option B: Power Query (Recommended for Automation)

1. **In Power BI Desktop**
   - Get Data → Web (blank)
   - Enter URL: `https://raw.githubusercontent.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase/main/data/exports/parquet/Employees.csv`

2. **Load All Tables**
   - Repeat for each table:
     - Contributions
     - DigitalAssets
     - Projects

3. **Transform if Needed**
   - Verify data types
   - Handle any nulls
   - Click "Close & Apply"

4. **Publish to Workspace**
   - File → Publish
   - Select workspace
   - Wait for completion

---

## STEP 2: CONFIGURE SEMANTIC MODEL (10 minutes)

### Add Relationships

1. **Open Semantic Model**
   - Go to workspace
   - Find semantic model: "employee_knowledge_semantic_model"
   - Or use ID: 21e0a7be-1e7d-4110-8faa-d835f81c6559
   - Click to open

2. **Switch to Model View**
   - Look for "Model" or "Edit" option
   - You should see all 4 tables: Employees, Contributions, DigitalAssets, Projects

3. **Add Relationship 1**
   - From: `Contributions` table
   - From Column: `employeeId`
   - To: `Employees` table
   - To Column: `employeeId`
   - Cardinality: Many-to-One
   - Cross filter: Both
   - Click Save

4. **Add Relationship 2**
   - From: `DigitalAssets` table
   - From Column: `employeeId`
   - To: `Employees` table
   - To Column: `employeeId`
   - Cardinality: Many-to-One
   - Cross filter: Both
   - Click Save

### Add Measures

1. **Add Measure 1: Total Employees**
   - In `Employees` table
   - Click "New Measure"
   - Name: `Total Employees`
   - Formula: `COUNTA(Employees[employeeId])`
   - Click Save

2. **Add Measure 2: Total Contributions**
   - In `Contributions` table
   - Click "New Measure"
   - Name: `Total Contributions`
   - Formula: `COUNTA(Contributions[contributionId])`
   - Click Save

3. **Add Measure 3: Avg Contribution Score**
   - In `Contributions` table
   - Click "New Measure"
   - Name: `Avg Contribution Score`
   - Formula: `AVERAGE(Contributions[score])`
   - Click Save

4. **Add Measure 4: Total Assets**
   - In `DigitalAssets` table
   - Click "New Measure"
   - Name: `Total Assets`
   - Formula: `COUNTA(DigitalAssets[assetId])`
   - Click Save

5. **Add Measure 5: Total Projects**
   - In `Projects` table
   - Click "New Measure"
   - Name: `Total Projects`
   - Formula: `COUNTA(Projects[projectId])`
   - Click Save

6. **Save Changes**
   - Click "Save" or use Ctrl+S

---

## STEP 3: CREATE POWER BI REPORTS (30 minutes)

### Report 1: Employee Skills Dashboard

1. **Create New Report**
   - From workspace, click "New" → "Report"
   - Select your semantic model
   - Click "Create"

2. **Add KPI Card: Total Employees**
   - Insert → KPI Card
   - Value field: `Measures[Total Employees]`
   - Format as needed

3. **Add Table: Employee Details**
   - Insert → Table
   - Fields: employeeId, name, department, role, skills, score
   - Name table "Employee List"

4. **Add Bar Chart: Contributions by Department**
   - Insert → Bar Chart
   - Axis: department
   - Value: `Measures[Total Contributions]`
   - Title: "Contributions by Department"

5. **Add Pie Chart: Employees by Tier**
   - Insert → Pie Chart
   - Legend: tier
   - Value: `Measures[Total Employees]`
   - Title: "Employees by Tier"

6. **Arrange Visuals**
   - Resize and position for readability
   - Ensure balanced layout

7. **Save Report**
   - File → Save or Ctrl+S
   - Name: "Employee Skills Dashboard"

### Report 2: Project Contribution Analysis

1. **Create New Report**
   - Click "New" → "Report"
   - Select your semantic model

2. **Add KPI Card: Total Projects**
   - Insert → KPI Card
   - Value: `Measures[Total Projects]`

3. **Add Table: Project Details**
   - Insert → Table
   - Fields: projectId, name, status, lead, team, startDate
   - Name table "Projects"

4. **Add Scatter Chart: Projects vs Contributions**
   - Insert → Scatter Chart
   - X-axis: project
   - Y-axis: `Measures[Total Contributions]`
   - Title: "Project Contribution Analysis"

5. **Add Bar Chart: Top 10 Employees**
   - Insert → Bar Chart
   - Axis: name
   - Value: `Measures[Total Contributions]`
   - Sort: Descending
   - Limit to top 10
   - Title: "Top 10 Contributors"

6. **Save Report**
   - Name: "Project Contribution Analysis"

### Report 3: Digital Assets Distribution

1. **Create New Report**
   - Click "New" → "Report"
   - Select your semantic model

2. **Add KPI Card: Total Assets**
   - Insert → KPI Card
   - Value: `Measures[Total Assets]`

3. **Add Pie Chart: Assets by Type**
   - Insert → Pie Chart
   - Legend: type
   - Value: `Measures[Total Assets]`
   - Title: "Assets by Type"

4. **Add Bar Chart: Assets by Owner**
   - Insert → Bar Chart
   - Axis: employeeId
   - Value: Count of assetId
   - Sort: Descending
   - Limit to top 20
   - Title: "Top Asset Owners"

5. **Add Table: Asset Catalog**
   - Insert → Table
   - Fields: assetId, name, type, owner, created, modified
   - Name table "Asset Details"

6. **Save Report**
   - Name: "Digital Assets Distribution"

---

## STEP 4: CREATE DASHBOARD (15 minutes)

### Create Main Dashboard

1. **Create New Dashboard**
   - Click "New" → "Dashboard"
   - Name: "Employee Knowledge Dashboard"
   - Click "Create"

2. **Pin Visuals from Employee Skills Dashboard**
   - Open "Employee Skills Dashboard" report
   - Click on "Total Employees" KPI card
   - Click Pin icon (looks like thumbtack)
   - Select dashboard: "Employee Knowledge Dashboard"
   - Repeat for:
     - "Contributions by Department" chart
     - "Employees by Tier" chart

3. **Pin Visuals from Project Analysis**
   - Open "Project Contribution Analysis" report
   - Pin these visuals:
     - "Total Projects" KPI
     - "Top 10 Contributors" chart

4. **Pin Visuals from Assets Report**
   - Open "Digital Assets Distribution" report
   - Pin these visuals:
     - "Total Assets" KPI
     - "Assets by Type" chart

5. **Arrange Dashboard**
   - Resize tiles for balanced layout
   - Group KPIs at top
   - Arrange charts below

6. **Format Dashboard**
   - Add title
   - Add description
   - Set theme/colors
   - Click "Save"

### Dashboard Layout (Suggested)

```
┌─────────────┬─────────────┬─────────────┐
│   Total     │   Total     │   Total     │
│  Employees  │  Projects   │   Assets    │
│   (100)     │     (20)    │    (800)    │
└─────────────┴─────────────┴─────────────┘
┌──────────────────┬──────────────────────┐
│ Contributions    │ Employees by Tier    │
│ by Department    │    (Pie Chart)       │
│  (Bar Chart)     │                      │
└──────────────────┴──────────────────────┘
┌──────────────────┬──────────────────────┐
│ Top 10           │ Assets by Type       │
│ Contributors     │    (Pie Chart)       │
│  (Bar Chart)     │                      │
└──────────────────┴──────────────────────┘
```

---

## STEP 5: PUBLISH POWER BI APP (5 minutes)

### Create App

1. **Open Apps**
   - Go to workspace
   - Click "Apps"
   - Click "Create app"

2. **Configure App**
   - Name: "Employee Knowledge App"
   - Description: "Enterprise employee knowledge and insights platform"
   - Logo: (optional, upload company logo)
   - Contact info: (your email)

3. **Add Content**
   - Navigation → Add Reports:
     - Employee Skills Dashboard
     - Project Contribution Analysis
     - Digital Assets Distribution
   - Navigation → Add Dashboard:
     - Employee Knowledge Dashboard

4. **Set Permissions**
   - Who has access:
     - Selected users/groups
     - Add team members or departments
   - Permissions:
     - View (read-only) - default
   - Click "Next"

5. **Review & Publish**
   - Review all settings
   - Click "Publish app"
   - Wait for publishing to complete

6. **Share App Link**
   - After publishing, copy app URL
   - Share with team members
   - URL format: `https://app.powerbi.com/groups/me/apps/[AppId]`

---

## VERIFICATION CHECKLIST

After completing all steps:

- [ ] All 4 tables loaded to OneLake (1,020 rows)
- [ ] Semantic model has 2 relationships configured
- [ ] Semantic model has 5 measures created
- [ ] 3 reports created with all visuals
- [ ] Main dashboard created with 7+ visuals
- [ ] Power BI app published and shared
- [ ] All visuals displaying data correctly
- [ ] Dashboard accessible to team

---

## TROUBLESHOOTING

### Data Not Loading to OneLake
- Verify you have write permissions to lakehouse
- Check file format (must be CSV with headers)
- Ensure column names match table schema

### Relationships Not Working
- Verify column data types match (both should be same type)
- Check for null values in foreign keys
- Use "Many-to-One" cardinality

### Reports Not Showing Data
- Confirm semantic model relationships are active
- Check measure formulas for syntax errors
- Verify data types in columns

### Dashboard Not Updating
- Refresh dashboard: Click refresh icon
- Check underlying report data
- Verify measures are calculating correctly

---

## NEXT STEPS AFTER DEPLOYMENT

1. **Set Up Refresh Schedule**
   - Workspace settings → Scheduled refresh
   - Set daily refresh for semantic model

2. **Add Row-Level Security (RLS)**
   - Semantic model → Row-Level Security
   - Add roles if needed (e.g., department managers)

3. **Create Additional Reports**
   - Add custom reports per user need
   - Pin to existing dashboard

4. **Monitor Performance**
   - Check Power BI Premium capacity usage
   - Monitor query performance

5. **Team Training**
   - Train team on using dashboard
   - Explain report interactions
   - Share interpretation guide

---

## RESOURCES

| Resource | Location |
|----------|----------|
| API Documentation | [api/README.md](../api/README.md) |
| Data Files | [data/exports/parquet/](../data/exports/parquet/) |
| Ontology Definition | [fabric/ontology/fabric_iq_ontology_complete.json](../fabric/ontology/fabric_iq_ontology_complete.json) |
| Power BI Config | [fabric/powerbi/powerbi_reports_config.json](../fabric/powerbi/powerbi_reports_config.json) |
| Deployment Script | [scripts/deploy-fabric-powerbi.ps1](../scripts/deploy-fabric-powerbi.ps1) |

---

## SUPPORT

For issues or questions:
1. Check [FABRIC_DEPLOYMENT_GUIDE.md](FABRIC_DEPLOYMENT_GUIDE.md)
2. Review [POWERBI_SETUP_GUIDE.md](POWERBI_SETUP_GUIDE.md)
3. Check GitHub: https://github.com/csdmichael/Fabric-IQ-Ontology-EmployeeKnowledge-UseCase

---

**Status**: Ready for deployment ✓  
**Last Updated**: May 10, 2026  
**Estimated Time**: 70 minutes
