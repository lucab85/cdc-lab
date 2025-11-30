# CI/CD

This directory contains CI scripts for the CDC Lab project.

## Schema Validation

The `validate_schemas.py` script validates Avro schema files:

```bash
python ci/validate_schemas.py
```

## GitHub Actions

Workflows are located in `.github/workflows/`:

- **validate-schemas.yml**: Validates Avro schemas on push/PR to main