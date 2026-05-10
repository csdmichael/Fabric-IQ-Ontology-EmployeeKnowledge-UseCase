
# FABRIC ONELAKE DATA DEPLOYMENT GUIDE

## Current Status
[OK] Data loaded from 4 JSON sources (1,020 records)
[OK] Ontology defined with relationships
[OK] Data pipeline configured (4 stages)
[OK] Power BI reports configured (11 visuals)
[OK] Dashboards ready for creation

## Step 1: Load Data into OneLake (Manual via Power BI Portal)

### Option A: Quick Upload
1. Go to: https://app.powerbi.com
2. Navigate to workspace
3. Go to Lakehouse
4. Click "Get Data" → "Upload files"
5. Upload CSV files from: data/exports/parquet/
   - Employees.csv (100 rows)
   - Contributions.csv (100 rows)
   - DigitalAssets.csv (800 rows)
   - Projects.csv (20 rows)
6. Map each file to corresponding OneLake table

### Option B: Power Query (Recommended)
1. In Power BI Desktop or Online:
   - New → Get Data → Web (blank)
   - Paste: fabric/powerbi/PowerQuery_OneLake_Loader.m
   - Replace DataSource URL with your GitHub raw content URL
   - Load all 4 queries
2. Transform as needed
3. Click "Close & Apply"
4. Publish to workspace

## Step 2: Configure Semantic Model

1. Go to semantic model: 21e0a7be-1e7d-4110-8faa-d835f81c6559
2. In Model view:
   - Add relationships from ontology:
     * Contributions[employeeId] → Employees[employeeId]
     * DigitalAssets[employeeId] → Employees[employeeId]
   - Add measures from powerbi_reports_config.json:
     * Total Employees
     * Total Contribution Score
     * Avg Employee Score
     * Total Assets
     * Total Projects

## Step 3: Update Power BI Reports

### Report 1: Employee Skills Dashboard
1. Open in edit mode
2. Add visuals from config:
   - KPI Card: Total Employees
   - Table: Employee name, department, role, skills, score
   - Bar Chart: Contributions by Department
   - Pie Chart: Employees by Tier
3. Save

### Report 2: Project Contribution Analysis
1. Open in edit mode
2. Add visuals:
   - KPI Card: Total Projects
   - Table: Project name, status, lead
   - Scatter: Projects vs Contributions
   - Bar: Top 10 employees by projects
3. Save

### Report 3: Digital Assets Distribution
1. Open in edit mode
2. Add visuals:
   - KPI Card: Total Assets
   - Pie: Assets by Type
   - Bar: Assets by Employee
   - Table: Asset catalog
3. Save

## Step 4: Create Dashboards

1. New Dashboard: "Employee Knowledge Dashboard"
2. From Employee Skills Dashboard report:
   - Pin "Total Employees" KPI
   - Pin "Contributions by Department" chart
   - Pin "Employees by Tier" chart
3. From Project Analysis:
   - Pin "Total Projects" KPI
   - Pin "Top 10 Employees" chart
4. From Assets:
   - Pin "Total Assets" KPI
   - Pin "Assets by Type" chart
5. Arrange, format, and save

## Step 5: Create Power BI App

1. Go to Apps → Create App
2. Fill in:
   - App Name: "Employee Knowledge App"
   - Description: "Enterprise employee knowledge and insights platform"
   - Logo: (optional)
3. Navigation:
   - Add dashboards
   - Add reports
   - Organize by section
4. Permissions:
   - Share with: Entire organization / Specific groups
5. Publish

## Step 6: Data Refresh Schedule

1. Set up refresh schedule for OneLake data
2. Configure Power BI to refresh:
   - Daily: Employee data updates
   - Weekly: Contribution scores recalculation
   - As needed: Asset catalog updates

## Configuration Files Reference

| File | Purpose |
|------|---------|
| fabric/ontology/fabric_iq_ontology_complete.json | Ontology with relationships & measures |
| fabric/pipelines/employee_knowledge_pipeline_complete.json | Data pipeline stages |
| fabric/powerbi/powerbi_reports_config.json | Report & visual definitions |
| fabric/powerbi/PowerQuery_OneLake_Loader.m | Power Query M script for data loading |
## Configuration Files Reference

| File | Purpose |
|------|---------|
| fabric/ontology/fabric_iq_ontology_complete.json | Ontology with relationships & measures |
| fabric/pipelines/employee_knowledge_pipeline_complete.json | Data pipeline stages |
| fabric/powerbi/powerbi_reports_config.json | Report & visual definitions |
| fabric/powerbi/PowerQuery_OneLake_Loader.m | Power Query M script for data loading |
| data/exports/parquet/* | CSV files ready for upload |

---
**Status**: Ready for data loading and deployment
**Last Updated**: May 10, 2026
