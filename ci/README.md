# CI/CD Workflows

This directory contains GitHub Actions workflows and CI/CD related scripts for the CDC Lab project.

## Workflows

### `github-actions-ci.yml`
**Main CI Pipeline** - Runs on pushes and PRs to main/develop branches.

- **validate-schemas**: Validates Avro schema files for correctness
- **validate-docker-compose**: Ensures docker-compose.yml is valid
- **lint-sql**: Basic syntax check for SQL files
- **validate-json**: Validates JSON configuration files
- **check-file-permissions**: Ensures scripts have correct executable permissions

### `github-actions-schema-check.yml`
**Schema Validation** - Runs when Avro schema files or validation script changes.

- Validates Avro schemas using the `validate_schemas.py` script
- Checks for schema evolution best practices

### `github-actions-docker-test.yml`
**Docker Compose Testing** - Runs when Docker-related files change.

- Builds Flink Docker image
- Starts essential services (PostgreSQL, Kafka, etc.)
- Tests service connectivity and health
- Validates Kafka Connect and Trino functionality

### `github-actions-security.yml`
**Security Scanning** - Runs weekly and on manual trigger.

- **security-scan**: Uses Trivy to scan for vulnerabilities
- **dependency-check**: Checks for outdated Docker images
- **python-security**: Audits Python dependencies for security issues

### `github-actions-updates.yml`
**Dependency Updates** - Runs daily and on manual trigger.

- Checks for Docker image updates
- Monitors Python dependencies
- Creates issues for manual review when updates are available

## Scripts

### `validate_schemas.py`
Python script for validating Avro schemas:
- JSON syntax validation
- Schema structure checks
- Schema evolution best practices
- Optional fastavro-based full validation

## Usage

### Running Locally

```bash
# Validate schemas
python ci/validate_schemas.py

# Validate Docker Compose
docker compose config --quiet

# Test services (requires Docker)
docker compose up -d
# ... run tests ...
docker compose down -v
```

### Manual Workflow Triggers

All workflows can be triggered manually from the GitHub Actions tab, except for scheduled ones.

## Configuration

- Workflows use Ubuntu latest runners
- Python 3.11 for schema validation
- Docker Buildx for image building
- Trivy for security scanning

## Adding New Workflows

1. Create new `.yml` file in this directory
2. Follow naming convention: `github-actions-<purpose>.yml`
3. Update this README
4. Test the workflow on a feature branch

## Dependabot

Configured in `.github/dependabot.yml` to automatically check for:
- Docker image updates
- GitHub Actions updates
- Python package updates (when requirements files are added)