# Power BI App Setup Guide - Quick Start

## Current Status
✅ **API Running**: https://fabric-iq-emp-knowledge-api.azurewebsites.net/health  
✅ **Fabric Workspace**: 38362838-0531-4215-89af-a8a79221b545  
✅ **OneLake Lakehouse**: d11b209f-c774-481e-adcb-79920a94fd20  
✅ **Data Ready**: 1,020 rows (Employees, Contributions, DigitalAssets, Projects)  
✅ **Power BI Reports**: 3 reports created (see below)

---

## Step 1: Go to Power BI Portal
1. Open: https://app.powerbi.com
2. Sign in with your organizational account
3. Go to your workspace (or create new)

---

## Step 2: Load Data into OneLake
### Option A: Quick Manual Upload (Fastest)
1. Go to **Workspaces** → Your workspace → **Lakehouse**
2. For each table (Employees, Contributions, DigitalAssets, Projects):
   - Click **Get Data** → **Upload files**
   - Upload from: `data/employees.json`, etc.
   - Map JSON to table schema
   - Click **Load**

### Option B: Power Query Dataflow (Recommended)
1. Go to **Workspaces** → Your workspace
2. Click **+ New** → **Dataflow Gen2**
3. Click **Import from text/CSV/JSON**
4. Upload each `data/*.json` file
5. Map columns to table schema:
   - Employees: employeeId, displayName, department, role, location, skills, hireDate
   - Contributions: employeeId, projectCount, assetCount, contributionScore, tier
   - DigitalAssets: assetId, employeeId, assetType, title, lastModified
   - Projects: projectId, name, description, status
6. Click **Create** → Tables will auto-populate

### Option C: Python SDK (For Automation)
```python
from fabric_client import FabricClient
import pandas as pd

client = FabricClient(workspace_id="38362838-0531-4215-89af-a8a79221b545")
lakehouse = client.get_lakehouse(lakehouse_id="d11b209f-c774-481e-adcb-79920a94fd20")

# Load each JSON file
employees_df = pd.read_json("data/employees.json")
lakehouse.write_table(employees_df, table_name="Employees")
```

---

## Step 3: Create Power BI Reports
Your 3 reports are already created and ready for editing:

### Report 1: Employee Skills Dashboard
**Purpose**: Show employee skills, departments, and contribution metrics
**Recommended Visuals**:
- KPI Card: Total Employees (100)
- Table: Employee Name, Department, Skills, Contribution Score
- Bar Chart: Contributions by Department
- Pie Chart: Employee Distribution by Role

### Report 2: Project Contribution Analysis
**Purpose**: Show project involvement and team structure
**Recommended Visuals**:
- KPI Card: Total Projects (20)
- Scatter Plot: Project vs Employee Contributions
- Bar Chart: Projects by Department
- Matrix: Project → Employee involvement

### Report 3: Digital Assets Distribution
**Purpose**: Show document types and asset inventory
**Recommended Visuals**:
- KPI Card: Total Assets (800)
- Pie Chart: Asset Types (pptx, pdf, excel, etc.)
- Bar Chart: Assets by Employee
- Table: Asset ID, Type, Title, Employee

---

## Step 4: Create Dashboards
1. In Power BI, go to **Dashboards** → **+ New Dashboard**
2. Name it: `Employee Knowledge Dashboard`
3. Click **Pin visuals**
4. From each report above, pin 3-4 key visuals
5. Arrange into a professional layout
6. Click **Save**

---

## Step 5: Create and Publish the App
1. Go to **Apps** → **Create app**
2. Fill in details:
   - **App name**: Employee Knowledge App
   - **Description**: Employee knowledge management and insights platform
   - **App logo**: (optional)
3. Go to **Navigation** tab:
   - Add your reports (click each report)
   - Add your dashboards (click each dashboard)
4. Go to **Permissions** tab:
   - Choose who can view (Entire organization / Specific groups)
5. Click **Publish app**

---

## Step 6: Share with Users
1. After publishing, click **Share app**
2. Send app link to your organization
3. Users can now view the Employee Knowledge App from:
   - https://app.powerbi.com/apps

---

## Verification Checklist

- [ ] OneLake tables are populated (1,020 rows total)
- [ ] Power BI reports show data correctly
- [ ] Dashboards display key metrics and visualizations
- [ ] Power BI App is published
- [ ] App is accessible to intended users
- [ ] API is responding (Health check: /health)
- [ ] Reports pull data from OneLake Lakehouse

---

## Troubleshooting

### "Data not showing in reports"
- Check if OneLake tables are populated
- Verify semantic model is connected to lakehouse
- Click **Refresh** on report visuals

### "Reports are blank"
- Go to Power BI Report Editor
- Click **Select Data** to add fields to visuals
- Drag columns from tables to chart axes

### "App not published"
- Ensure at least one report or dashboard is added to app
- Check workspace access permissions
- Try publishing again from Apps tab

---

## Quick Command Reference

```powershell
# Check API status
Invoke-WebRequest -Uri "https://fabric-iq-emp-knowledge-api.azurewebsites.net/health"

# Open Fabric workspace in browser
Start-Process "https://app.powerbi.com/groups/me/workspaces"

# View deployment status
cat DEPLOYMENT_STATUS.md
```

---

**Estimated Time to Complete**: 15-20 minutes  
**Complexity**: Low (mostly UI clicks in Power BI Portal)  
**Last Updated**: May 10, 2026
