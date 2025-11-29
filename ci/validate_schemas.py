#!/usr/bin/env python3
"""
Schema validation script for CI pipelines.
Validates Avro schemas for correctness and compatibility best practices.
"""
import sys
import json
from pathlib import Path

def validate_avro_schema(schema_path):
    """Validate an Avro schema file."""
    try:
        import fastavro
        HAS_FASTAVRO = True
    except ImportError:
        HAS_FASTAVRO = False
    
    try:
        with open(schema_path) as f:
            schema = json.load(f)
        
        # Basic JSON structure validation
        if 'type' not in schema:
            print(f"Schema {schema_path} is INVALID: missing 'type' field")
            return False
        
        if schema['type'] == 'record' and 'fields' not in schema:
            print(f"Schema {schema_path} is INVALID: record type missing 'fields'")
            return False
        
        # If fastavro is available, do full validation
        if HAS_FASTAVRO:
            fastavro.parse_schema(schema)
        
        # Check for schema evolution best practices
        warnings = []
        if schema['type'] == 'record':
            for field in schema.get('fields', []):
                field_name = field.get('name', 'unknown')
                field_type = field.get('type')
                
                # Check if new fields have defaults
                if isinstance(field_type, list) and 'null' in field_type:
                    if 'default' not in field:
                        warnings.append(f"  ⚠ Field '{field_name}' is nullable but has no default")
        
        print(f"✓ Schema {schema_path} is valid")
        for warning in warnings:
            print(warning)
        return True
        
    except json.JSONDecodeError as e:
        print(f"✗ Schema {schema_path} is INVALID: JSON parse error - {e}")
        return False
    except Exception as e:
        print(f"✗ Schema {schema_path} is INVALID: {e}")
        return False

def main():
    """Main entry point."""
    if len(sys.argv) > 1:
        schema_dir = Path(sys.argv[1])
    else:
        schema_dir = Path("./schemas")
    
    if not schema_dir.exists():
        print(f"Schema directory not found: {schema_dir}")
        sys.exit(1)
    
    all_valid = True
    schema_files = list(schema_dir.glob("*.avsc"))
    
    if not schema_files:
        print(f"No .avsc files found in {schema_dir}")
        sys.exit(0)
    
    print(f"Validating schemas in {schema_dir}...")
    print("-" * 40)
    
    for schema_file in schema_files:
        if not validate_avro_schema(schema_file):
            all_valid = False
    
    print("-" * 40)
    if all_valid:
        print("All schemas are valid!")
        sys.exit(0)
    else:
        print("Some schemas failed validation!")
        sys.exit(1)

if __name__ == "__main__":
    main()
