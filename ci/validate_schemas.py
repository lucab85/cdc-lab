import sys
import json
from pathlib import Path

def validate_avro_schema(schema_path):
    try:
        import fastavro
    except ImportError:
        print("fastavro not installed. Please install with 'pip install fastavro'.")
        return False
    try:
        with open(schema_path) as f:
            schema = json.load(f)
        fastavro.parse_schema(schema)
        print(f"Schema {schema_path} is valid.")
        return True
    except Exception as e:
        print(f"Schema {schema_path} is INVALID: {e}")
        return False

def main():
    schema_dir = Path("./schemas")
    all_valid = True
    for schema_file in schema_dir.glob("*.avsc"):
        if not validate_avro_schema(schema_file):
            all_valid = False
    if not all_valid:
        sys.exit(1)

if __name__ == "__main__":
    main()
