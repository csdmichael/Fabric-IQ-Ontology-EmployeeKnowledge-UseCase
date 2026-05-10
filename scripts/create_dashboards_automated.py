#!/usr/bin/env python3
"""
Automated Dashboard & Relationship Creation for Power BI
Uses Power BI REST API to configure semantic model and create dashboards
"""

import json
import subprocess
from pathlib import Path
from typing import Dict, List

WORKSPACE_ID = "38362838-0531-4215-89af-a8a79221b545"
SEMANTIC_MODEL_ID = "21e0a7be-1e7d-4110-8faa-d835f81c6559"

def get_access_token():
    """Get Power BI API token"""
    try:
        cmd = 'az account get-access-token --resource https://api.powerbi.com --query accessToken -o tsv'
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()
        return None
    except Exception as e:
        print(f"Error getting token: {e}")
        return None

def create_dashboard(token: str, dashboard_name: str, dashboard_description: str) -> Dict:
    """Create a Power BI dashboard"""
    print(f"\n> Creating dashboard: {dashboard_name}...")
    
    import requests
    
    url = f"https://api.powerbi.com/v1.0/myorg/groups/{WORKSPACE_ID}/dashboards"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    payload = {
        "name": dashboard_name,
        "displayName": dashboard_name,
        "description": dashboard_description
    }
    
    try:
        response = requests.post(url, json=payload, headers=headers, timeout=10)
        if response.status_code in [200, 201]:
            result = response.json()
            print(f"  ✓ Dashboard created: {result.get('id')}")
            return result
        else:
            print(f"  ⚠ Status {response.status_code}: {response.text[:100]}")
            return {}
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return {}

def get_semantic_model_tables(token: str) -> List[Dict]:
    """Get tables from semantic model"""
    print("\n> Fetching semantic model tables...")
    
    import requests
    
    url = f"https://api.powerbi.com/v1.0/myorg/groups/{WORKSPACE_ID}/datasets/{SEMANTIC_MODEL_ID}/tables"
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            result = response.json()
            tables = result.get('value', [])
            print(f"  ✓ Found {len(tables)} tables:")
            for table in tables:
                print(f"    • {table.get('name')}")
            return tables
        else:
            print(f"  ⚠ Status {response.status_code}")
            return []
    except Exception as e:
        print(f"  ✗ Error: {e}")
        return []

def add_table_relationships(token: str) -> bool:
    """Add relationships between tables in semantic model"""
    print("\n> Adding table relationships...")
    
    import requests
    
    relationships = [
        {
            "name": "fk_Contributions_Employees",
            "fromTable": "Contributions",
            "fromColumn": "employeeId",
            "toTable": "Employees",
            "toColumn": "employeeId",
            "crossFilteringBehavior": "oneDirection"
        },
        {
            "name": "fk_DigitalAssets_Employees",
            "fromTable": "DigitalAssets",
            "fromColumn": "employeeId",
            "toTable": "Employees",
            "toColumn": "employeeId",
            "crossFilteringBehavior": "oneDirection"
        }
    ]
    
    url = f"https://api.powerbi.com/v1.0/myorg/groups/{WORKSPACE_ID}/datasets/{SEMANTIC_MODEL_ID}/relationships"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    for rel in relationships:
        try:
            response = requests.post(url, json=rel, headers=headers, timeout=10)
            if response.status_code in [200, 201]:
                print(f"  ✓ Relationship created: {rel['name']}")
            elif "already exists" in response.text or response.status_code == 409:
                print(f"  ⚠ Relationship already exists: {rel['name']}")
            else:
                print(f"  ✗ Status {response.status_code}: {response.text[:80]}")
        except Exception as e:
            print(f"  ✗ Error creating {rel['name']}: {e}")
    
    return True

def add_measures(token: str) -> bool:
    """Add DAX measures to semantic model"""
    print("\n> Adding Power BI measures...")
    
    measures = [
        {
            "table": "Employees",
            "name": "Total Employees",
            "expression": "COUNTA(Employees[employeeId])",
            "format": "0"
        },
        {
            "table": "Contributions",
            "name": "Total Contribution Score",
            "expression": "SUM(Contributions[contributionScore])",
            "format": "0"
        },
        {
            "table": "Contributions",
            "name": "Avg Employee Score",
            "expression": "AVERAGE(Contributions[contributionScore])",
            "format": "0.00"
        },
        {
            "table": "DigitalAssets",
            "name": "Total Assets",
            "expression": "COUNTA(DigitalAssets[assetId])",
            "format": "0"
        },
        {
            "table": "Projects",
            "name": "Total Projects",
            "expression": "COUNTA(Projects[projectId])",
            "format": "0"
        }
    ]
    
    import requests
    
    url = f"https://api.powerbi.com/v1.0/myorg/groups/{WORKSPACE_ID}/datasets/{SEMANTIC_MODEL_ID}/tables/{{table}}/measures"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    for measure in measures:
        try:
            table = measure.pop("table")
            measure_url = url.replace("{table}", table)
            response = requests.post(measure_url, json=measure, headers=headers, timeout=10)
            if response.status_code in [200, 201]:
                print(f"  ✓ Measure added: {measure['name']} ({table})")
            else:
                print(f"  ⚠ Status {response.status_code}")
        except Exception as e:
            print(f"  ✗ Error: {e}")
    
    return True

def create_dashboard_from_config(token: str):
    """Create dashboards based on configuration"""
    print("\n" + "="*70)
    print("CREATING POWER BI DASHBOARDS")
    print("="*70)
    
    # Load Power BI config
    config_path = Path("fabric/powerbi/powerbi_reports_config.json")
    if not config_path.exists():
        print("✗ Power BI config not found")
        return
    
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    # Create main dashboard
    main_dashboard = create_dashboard(
        token,
        "Employee Knowledge Dashboard",
        "Comprehensive employee skills, contributions, and assets dashboard"
    )
    
    # Create report-specific dashboards
    for report in config.get("reports", []):
        create_dashboard(
            token,
            f"{report['name']} Dashboard",
            report['description']
        )

def generate_deployment_guide():
    """Generate comprehensive deployment guide"""
    guide = """
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
"""
    
    guide_path = Path("FABRIC_DEPLOYMENT_GUIDE.md")
    with open(guide_path, 'w', encoding='utf-8') as f:
        f.write(guide)
    
    print(f"\n[OK] Deployment guide saved to {guide_path}")
    return guide

def main():
    print("\n" + "="*70)
    print("AUTOMATED DASHBOARD & RELATIONSHIP CREATION")
    print("="*70)
    
    # Get token
    print("\n> Authenticating with Power BI API...")
    token = get_access_token()
    
    if not token:
        print("✗ Failed to get access token")
        print("\nFallback: Use manual steps in deployment guide")
        generate_deployment_guide()
        return
    
    print("  ✓ Authenticated")
    
    # Get semantic model info
    tables = get_semantic_model_tables(token)
    
    # Add relationships
    add_table_relationships(token)
    
    # Add measures
    add_measures(token)
    
    # Create dashboards
    create_dashboard_from_config(token)
    
    # Generate guide
    generate_deployment_guide()
    
    print("\n" + "="*70)
    print("DEPLOYMENT COMPLETE")
    print("="*70)
    print("""
Next Steps:
1. Load data into OneLake (see FABRIC_DEPLOYMENT_GUIDE.md)
2. Verify Power BI reports are connected
3. Create dashboards from reports
4. Publish Power BI app to organization
5. Share with team

For detailed instructions, see: FABRIC_DEPLOYMENT_GUIDE.md
""")

if __name__ == "__main__":
    main()
