#!/usr/bin/env python3
"""
Fabric OneLake Data Loading & Ontology Setup
Loads employee knowledge data and creates semantic model relationships
"""

import json
import pandas as pd
from pathlib import Path
import os
from datetime import datetime

# Configuration
WORKSPACE_ID = "38362838-0531-4215-89af-a8a79221b545"
LAKEHOUSE_ID = "d11b209f-c774-481e-adcb-79920a94fd20"
SEMANTIC_MODEL_ID = "21e0a7be-1e7d-4110-8faa-d835f81c6559"

def load_json_to_dataframe(file_path):
    """Load JSON file and convert to DataFrame"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return pd.DataFrame(data if isinstance(data, list) else [data])
    except Exception as e:
        print(f"  ✗ Error loading {file_path}: {e}")
        return None

def prepare_onelake_tables():
    """Prepare and validate all OneLake tables"""
    print("\n" + "="*70)
    print("STEP 1: PREPARE ONELAKE TABLES")
    print("="*70)
    
    data_dir = Path("data")
    tables = {}
    
    # Load Employees
    print("\n→ Loading Employees table...")
    employees_df = load_json_to_dataframe(data_dir / "employees.json")
    if employees_df is not None:
        # Normalize skills (handle list/string)
        employees_df['skills'] = employees_df['skills'].apply(
            lambda x: ','.join(x) if isinstance(x, list) else str(x)
        )
        tables['Employees'] = employees_df
        print(f"  ✓ Loaded {len(employees_df)} employees")
        print(f"    Columns: {list(employees_df.columns)[:5]}")
    
    # Load Contributions
    print("\n→ Loading Contributions table...")
    contributions_df = load_json_to_dataframe(data_dir / "contributions.json")
    if contributions_df is not None:
        # Handle projectIds array
        if 'projectIds' in contributions_df.columns:
            contributions_df['projectCount'] = contributions_df['projectIds'].apply(
                lambda x: len(x) if isinstance(x, list) else 0
            )
            contributions_df = contributions_df.drop(columns=['projectIds'], errors='ignore')
        tables['Contributions'] = contributions_df
        print(f"  ✓ Loaded {len(contributions_df)} contribution records")
    
    # Load Digital Assets
    print("\n→ Loading DigitalAssets table...")
    assets_df = load_json_to_dataframe(data_dir / "digital_assets.json")
    if assets_df is not None:
        # Flatten nested storageRef
        if 'storageRef' in assets_df.columns:
            assets_df = assets_df.drop(columns=['storageRef'], errors='ignore')
        tables['DigitalAssets'] = assets_df
        print(f"  ✓ Loaded {len(assets_df)} digital assets")
    
    # Load Projects
    print("\n→ Loading Projects table...")
    projects_df = load_json_to_dataframe(data_dir / "projects.json")
    if projects_df is not None:
        # Rename 'name' to 'projectName' if present
        if 'name' in projects_df.columns:
            projects_df = projects_df.rename(columns={'name': 'projectName'})
        tables['Projects'] = projects_df
        print(f"  ✓ Loaded {len(projects_df)} projects")
    
    return tables

def create_ontology(tables):
    """Create ontology/data model relationships"""
    print("\n" + "="*70)
    print("STEP 2: CREATE ONTOLOGY & DATA RELATIONSHIPS")
    print("="*70)
    
    ontology = {
        "workspace_id": WORKSPACE_ID,
        "lakehouse_id": LAKEHOUSE_ID,
        "semantic_model_id": SEMANTIC_MODEL_ID,
        "created": datetime.now().isoformat(),
        "tables": {},
        "relationships": [],
        "measures": []
    }
    
    # Define table schemas with business keys
    print("\n→ Defining table schemas...")
    
    ontology["tables"]["Employees"] = {
        "columns": ["employeeId", "displayName", "email", "department", "role", 
                   "location", "skills", "hireDate"],
        "primary_key": "employeeId",
        "business_key": "email"
    }
    print("  ✓ Employees (PK: employeeId)")
    
    ontology["tables"]["Contributions"] = {
        "columns": ["employeeId", "projectCount", "assetCount", "codeCommitCount", 
                   "contributionScore", "tier"],
        "primary_key": "employeeId",
        "foreign_keys": ["employeeId"]
    }
    print("  ✓ Contributions (PK: employeeId, FK: Employees.employeeId)")
    
    ontology["tables"]["DigitalAssets"] = {
        "columns": ["assetId", "employeeId", "assetType", "title", "lastModified"],
        "primary_key": "assetId",
        "foreign_keys": ["employeeId"]
    }
    print("  ✓ DigitalAssets (PK: assetId, FK: Employees.employeeId)")
    
    ontology["tables"]["Projects"] = {
        "columns": ["projectId", "projectName", "description", "status", "lead"],
        "primary_key": "projectId"
    }
    print("  ✓ Projects (PK: projectId)")
    
    # Define relationships
    print("\n→ Defining relationships...")
    
    ontology["relationships"] = [
        {
            "name": "FK_Contributions_Employees",
            "from_table": "Contributions",
            "from_column": "employeeId",
            "to_table": "Employees",
            "to_column": "employeeId",
            "cardinality": "many-to-one"
        },
        {
            "name": "FK_DigitalAssets_Employees",
            "from_table": "DigitalAssets",
            "from_column": "employeeId",
            "to_table": "Employees",
            "to_column": "employeeId",
            "cardinality": "many-to-one"
        }
    ]
    print("  ✓ Contributions → Employees")
    print("  ✓ DigitalAssets → Employees")
    
    # Define measures for Power BI
    print("\n→ Defining Power BI measures...")
    
    ontology["measures"] = [
        {
            "name": "Total Employees",
            "table": "Employees",
            "expression": "COUNTA(Employees[employeeId])",
            "format": "0"
        },
        {
            "name": "Total Contributions",
            "table": "Contributions",
            "expression": "SUM(Contributions[contributionScore])",
            "format": "0"
        },
        {
            "name": "Total Assets",
            "table": "DigitalAssets",
            "expression": "COUNTA(DigitalAssets[assetId])",
            "format": "0"
        },
        {
            "name": "Total Projects",
            "table": "Projects",
            "expression": "COUNTA(Projects[projectId])",
            "format": "0"
        },
        {
            "name": "Average Employee Score",
            "table": "Contributions",
            "expression": "AVERAGE(Contributions[contributionScore])",
            "format": "0.00"
        }
    ]
    print("  ✓ Total Employees")
    print("  ✓ Total Contributions")
    print("  ✓ Total Assets")
    print("  ✓ Total Projects")
    print("  ✓ Average Employee Score")
    
    # Save ontology definition
    ontology_path = Path("fabric/ontology/fabric_iq_ontology_complete.json")
    ontology_path.parent.mkdir(parents=True, exist_ok=True)
    with open(ontology_path, 'w') as f:
        json.dump(ontology, f, indent=2)
    print(f"\n✓ Ontology saved to {ontology_path}")
    
    return ontology

def create_dataflow_config(tables):
    """Create Fabric dataflow configuration"""
    print("\n" + "="*70)
    print("STEP 3: CREATE DATA PIPELINE CONFIGURATION")
    print("="*70)
    
    dataflow = {
        "name": "Employee Knowledge Data Pipeline",
        "description": "Fabric dataflow for ingesting employee knowledge data into OneLake",
        "created": datetime.now().isoformat(),
        "workspace_id": WORKSPACE_ID,
        "lakehouse_id": LAKEHOUSE_ID,
        "stages": [],
        "transformations": []
    }
    
    # Define pipeline stages
    print("\n→ Defining pipeline stages...")
    
    dataflow["stages"] = [
        {
            "stage": 1,
            "name": "Extract",
            "description": "Extract from JSON files in /data",
            "sources": [
                {"type": "json", "file": "data/employees.json", "table": "Employees"},
                {"type": "json", "file": "data/contributions.json", "table": "Contributions"},
                {"type": "json", "file": "data/digital_assets.json", "table": "DigitalAssets"},
                {"type": "json", "file": "data/projects.json", "table": "Projects"}
            ]
        },
        {
            "stage": 2,
            "name": "Transform",
            "description": "Clean and normalize data",
            "transformations": [
                {
                    "table": "Employees",
                    "rules": [
                        "Convert skills array to comma-separated string",
                        "Normalize email to lowercase",
                        "Parse hireDate to date format"
                    ]
                },
                {
                    "table": "Contributions",
                    "rules": [
                        "Ensure contributionScore is numeric",
                        "Fill null tier with 'standard'",
                        "Calculate projectCount from projectIds"
                    ]
                },
                {
                    "table": "DigitalAssets",
                    "rules": [
                        "Flatten storageRef structure",
                        "Normalize assetType to lowercase"
                    ]
                }
            ]
        },
        {
            "stage": 3,
            "name": "Load",
            "description": "Load into OneLake tables",
            "destination": "OneLake",
            "mode": "upsert",
            "key_columns": {
                "Employees": ["employeeId"],
                "Contributions": ["employeeId"],
                "DigitalAssets": ["assetId"],
                "Projects": ["projectId"]
            }
        },
        {
            "stage": 4,
            "name": "Validate",
            "description": "Data quality checks",
            "checks": [
                "No null employeeId in Employees",
                "ContributionScore between 0-100",
                "Valid email format",
                "Project status in [active, completed, pending]"
            ]
        }
    ]
    
    for stage in dataflow["stages"]:
        print(f"  ✓ Stage {stage['stage']}: {stage['name']}")
    
    # Save dataflow configuration
    pipeline_path = Path("fabric/pipelines/employee_knowledge_pipeline_complete.json")
    pipeline_path.parent.mkdir(parents=True, exist_ok=True)
    with open(pipeline_path, 'w') as f:
        json.dump(dataflow, f, indent=2)
    print(f"\n✓ Pipeline config saved to {pipeline_path}")
    
    return dataflow

def export_tables_for_powerbi(tables):
    """Export Parquet files for Power BI to load"""
    print("\n" + "="*70)
    print("STEP 4: PREPARE DATA FOR POWER BI")
    print("="*70)
    
    export_dir = Path("data/exports/parquet")
    export_dir.mkdir(parents=True, exist_ok=True)
    csv_export_dir = Path("data/exports")
    csv_export_dir.mkdir(parents=True, exist_ok=True)
    
    print("\n→ Exporting tables to Parquet format...")
    
    for table_name, df in tables.items():
        if df is not None:
            # Always produce a top-level CSV for deployment scripts that upload OneLake seed files.
            csv_name_map = {
                "Employees": "employees.csv",
                "Contributions": "contributions.csv",
                "DigitalAssets": "digital_assets.csv",
                "Projects": "projects.csv",
            }
            csv_path = csv_export_dir / csv_name_map.get(table_name, f"{table_name.lower()}.csv")
            try:
                df.to_csv(csv_path, index=False)
            except Exception as e:
                print(f"  ✗ Failed to export CSV {csv_path.name}: {e}")

            file_path = export_dir / f"{table_name}.parquet"
            try:
                df.to_parquet(file_path, index=False)
                print(f"  ✓ {table_name} ({len(df)} rows) → {file_path}")
            except ImportError:
                # If parquet not available, use CSV
                file_path = export_dir / f"{table_name}.csv"
                df.to_csv(file_path, index=False)
                print(f"  ✓ {table_name} ({len(df)} rows) → CSV")
            except Exception as e:
                print(f"  ✗ Failed to export {table_name}: {e}")
    
    return export_dir

def create_powerbi_config(tables, ontology):
    """Create Power BI report configuration"""
    print("\n" + "="*70)
    print("STEP 5: CREATE POWER BI REPORT CONFIGURATION")
    print("="*70)
    
    reports_config = {
        "workspace_id": WORKSPACE_ID,
        "semantic_model_id": SEMANTIC_MODEL_ID,
        "created": datetime.now().isoformat(),
        "reports": []
    }
    
    print("\n→ Configuring Power BI reports...")
    
    # Report 1: Employee Skills Dashboard
    reports_config["reports"].append({
        "name": "Employee Skills Dashboard",
        "description": "Employee skills, contributions, and career metrics",
        "pages": [
            {
                "name": "Overview",
                "visuals": [
                    {
                        "type": "card",
                        "title": "Total Employees",
                        "measure": "Total Employees"
                    },
                    {
                        "type": "card",
                        "title": "Average Contribution Score",
                        "measure": "Average Employee Score"
                    },
                    {
                        "type": "table",
                        "title": "Employee Skills Matrix",
                        "fields": ["displayName", "department", "role", "skills", "contributionScore"]
                    },
                    {
                        "type": "bar",
                        "title": "Contributions by Department",
                        "category": "department",
                        "measure": "Total Contributions"
                    }
                ]
            }
        ],
        "data_source": {
            "tables": ["Employees", "Contributions"],
            "relationships": ["FK_Contributions_Employees"]
        }
    })
    print("  ✓ Employee Skills Dashboard (4 visuals)")
    
    # Report 2: Project Contribution Analysis
    reports_config["reports"].append({
        "name": "Project Contribution Analysis",
        "description": "Project involvement and team collaboration metrics",
        "pages": [
            {
                "name": "Project View",
                "visuals": [
                    {
                        "type": "card",
                        "title": "Total Projects",
                        "measure": "Total Projects"
                    },
                    {
                        "type": "table",
                        "title": "Projects Overview",
                        "fields": ["projectName", "description", "status", "lead"]
                    },
                    {
                        "type": "scatter",
                        "title": "Project vs Employee Contributions",
                        "x_axis": "projectCount",
                        "y_axis": "contributionScore"
                    }
                ]
            }
        ],
        "data_source": {
            "tables": ["Projects", "Contributions", "Employees"],
            "relationships": ["FK_Contributions_Employees"]
        }
    })
    print("  ✓ Project Contribution Analysis (3 visuals)")
    
    # Report 3: Digital Assets Distribution
    reports_config["reports"].append({
        "name": "Digital Assets Distribution",
        "description": "Document and asset inventory across organization",
        "pages": [
            {
                "name": "Assets",
                "visuals": [
                    {
                        "type": "card",
                        "title": "Total Assets",
                        "measure": "Total Assets"
                    },
                    {
                        "type": "pie",
                        "title": "Assets by Type",
                        "category": "assetType",
                        "measure": "count"
                    },
                    {
                        "type": "bar",
                        "title": "Assets by Employee (Top 10)",
                        "category": "displayName",
                        "measure": "count",
                        "limit": 10
                    },
                    {
                        "type": "table",
                        "title": "Asset Catalog",
                        "fields": ["assetId", "displayName", "assetType", "title", "lastModified"]
                    }
                ]
            }
        ],
        "data_source": {
            "tables": ["DigitalAssets", "Employees"],
            "relationships": ["FK_DigitalAssets_Employees"]
        }
    })
    print("  ✓ Digital Assets Distribution (4 visuals)")
    
    # Save Power BI configuration
    powerbi_path = Path("fabric/powerbi/powerbi_reports_config.json")
    powerbi_path.parent.mkdir(parents=True, exist_ok=True)
    with open(powerbi_path, 'w') as f:
        json.dump(reports_config, f, indent=2)
    print(f"\n✓ Power BI config saved to {powerbi_path}")
    
    return reports_config

def create_summary(tables, ontology, dataflow, powerbi_config):
    """Generate comprehensive deployment summary"""
    print("\n" + "="*70)
    print("DEPLOYMENT SUMMARY")
    print("="*70)
    
    summary = {
        "timestamp": datetime.now().isoformat(),
        "workspace_id": WORKSPACE_ID,
        "lakehouse_id": LAKEHOUSE_ID,
        "semantic_model_id": SEMANTIC_MODEL_ID,
        "data_loaded": {
            "Employees": len(tables.get('Employees', pd.DataFrame())),
            "Contributions": len(tables.get('Contributions', pd.DataFrame())),
            "DigitalAssets": len(tables.get('DigitalAssets', pd.DataFrame())),
            "Projects": len(tables.get('Projects', pd.DataFrame()))
        },
        "total_records": sum(len(df) if df is not None else 0 for df in tables.values()),
        "ontology_created": True,
        "ontology_relationships": len(ontology["relationships"]),
        "ontology_measures": len(ontology["measures"]),
        "pipeline_stages": len(dataflow["stages"]),
        "powerbi_reports": len(powerbi_config["reports"]),
        "powerbi_visuals": sum(
            len(page.get("visuals", [])) 
            for report in powerbi_config["reports"] 
            for page in report.get("pages", [])
        ),
        "status": "READY FOR DEPLOYMENT"
    }
    
    print("\n✓ Data Loaded:")
    for table, count in summary["data_loaded"].items():
        print(f"  • {table}: {count:,} records")
    print(f"\n  TOTAL: {summary['total_records']:,} records")
    
    print(f"\n✓ Ontology:")
    print(f"  • {summary['ontology_relationships']} relationships defined")
    print(f"  • {summary['ontology_measures']} Power BI measures defined")
    
    print(f"\n✓ Data Pipeline:")
    print(f"  • {summary['pipeline_stages']} stages configured")
    
    print(f"\n✓ Power BI:")
    print(f"  • {summary['powerbi_reports']} reports")
    print(f"  • {summary['powerbi_visuals']} total visuals")
    
    print(f"\n✓ Status: {summary['status']}")
    
    # Save summary
    summary_path = Path("FABRIC_DEPLOYMENT_COMPLETE.json")
    with open(summary_path, 'w') as f:
        json.dump(summary, f, indent=2)
    
    return summary

def main():
    print("\n" + "█"*70)
    print("█  FABRIC ONELAKE DATA LOADING & ONTOLOGY SETUP")
    print("█"*70)
    
    # Step 1: Load data
    tables = prepare_onelake_tables()
    
    # Step 2: Create ontology
    ontology = create_ontology(tables)
    
    # Step 3: Create pipeline
    dataflow = create_dataflow_config(tables)
    
    # Step 4: Export for Power BI
    export_dir = export_tables_for_powerbi(tables)
    
    # Step 5: Create Power BI config
    powerbi_config = create_powerbi_config(tables, ontology)
    
    # Summary
    summary = create_summary(tables, ontology, dataflow, powerbi_config)
    
    print("\n" + "█"*70)
    print("█  NEXT STEPS")
    print("█"*70)
    print("\n1. LOAD DATA INTO ONELAKE:")
    print("   • Go to Power BI → Your Workspace → Lakehouse")
    print("   • Use 'Get Data' → 'Upload files'")
    print(f"   • Upload from: {export_dir}")
    print("   • Map to tables: Employees, Contributions, DigitalAssets, Projects")
    
    print("\n2. CONFIGURE SEMANTIC MODEL:")
    print("   • Go to Semantic Model settings")
    print("   • Add relationships from ontology definition")
    print("   • Add measures from Power BI config")
    
    print("\n3. UPDATE POWER BI REPORTS:")
    print("   • Open each report in edit mode")
    print("   • Add visuals from powerbi_reports_config.json")
    print("   • Configure drill-through between reports")
    
    print("\n4. CREATE DASHBOARDS:")
    print("   • Create 'Employee Knowledge Dashboard'")
    print("   • Pin key visuals from all 3 reports")
    print("   • Publish to shared dashboard")
    
    print("\n5. PUBLISH APP:")
    print("   • Go to Power BI → Apps → Create app")
    print("   • Add dashboards and reports")
    print("   • Publish to organization")
    
    print("\n" + "█"*70)
    print("█  FILES GENERATED")
    print("█"*70)
    print(f"\n  ✓ fabric/ontology/fabric_iq_ontology_complete.json")
    print(f"  ✓ fabric/pipelines/employee_knowledge_pipeline_complete.json")
    print(f"  ✓ fabric/powerbi/powerbi_reports_config.json")
    print(f"  ✓ data/exports/parquet/* (data files)")
    print(f"  ✓ FABRIC_DEPLOYMENT_COMPLETE.json (summary)")
    
    print("\n" + "█"*70 + "\n")

if __name__ == "__main__":
    main()
