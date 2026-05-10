#!/usr/bin/env python3
"""
Load JSON data files into Fabric OneLake tables
"""

import json
import sys
from pathlib import Path
from datetime import datetime

def load_data():
    """Load and summarize data files"""
    data_dir = Path("data")
    
    files_to_load = {
        "Employees": "employees.json",
        "Contributions": "contributions.json",
        "DigitalAssets": "digital_assets.json",
        "Projects": "projects.json",
    }
    
    print("=" * 70)
    print("ONELAKE DATA LOADING SUMMARY")
    print("=" * 70)
    print(f"\nTimestamp: {datetime.now().isoformat()}")
    print(f"Data Directory: {data_dir.absolute()}")
    
    total_rows = 0
    
    for table_name, file_name in files_to_load.items():
        file_path = data_dir / file_name
        
        if not file_path.exists():
            print(f"\n❌ {table_name:20} - FILE NOT FOUND: {file_name}")
            continue
        
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            
            # Handle both list and dict formats
            rows = data if isinstance(data, list) else [data]
            row_count = len(rows)
            total_rows += row_count
            
            print(f"\n✓ {table_name:20} - {row_count:5} rows ready to load")
            
            # Show sample keys
            if rows:
                keys = list(rows[0].keys())
                print(f"  Columns: {', '.join(keys[:5])}")
                
        except Exception as e:
            print(f"\n❌ {table_name:20} - ERROR: {str(e)}")
    
    print("\n" + "=" * 70)
    print(f"SUMMARY: {total_rows} total rows ready for OneLake ingestion")
    print("=" * 70)
    
    print("\nNEXT STEPS TO LOAD DATA:")
    print("  1. Via Fabric UI:")
    print("     - Go to Fabric workspace > Lakehouse")
    print("     - Use 'Get Data' > 'Upload files'")
    print("     - Upload each JSON file to corresponding table")
    print("")
    print("  2. Via Power Query (Recommended):")
    print("     - Create a Power Query dataflow")
    print("     - Load JSON files from data/ folder")
    print("     - Map to OneLake tables")
    print("")
    print("  3. Via Python SDK:")
    print("     - Use fabric-client package")
    print("     - Connect to workspace and lakehouse")
    print("     - Use pd.read_json() → write to delta tables")

if __name__ == "__main__":
    load_data()
