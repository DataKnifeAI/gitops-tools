# Harbor Secrets

This directory contains reference templates for Harbor secrets.

## Files

- `harbor-credentials.yaml.example` - Template for Harbor credentials secret

## Usage

### Option 1: Using .env file (Recommended)

1. Copy the example file at project root:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your actual passwords:
   ```bash
   nano .env
   ```

3. Create the secret using the script:
   ```bash
   ./scripts/create-harbor-secrets.sh
   ```

### Option 2: Using YAML file

1. Copy the example file:
   ```bash
   cp secrets/harbor/harbor-credentials.yaml.example secrets/harbor/harbor-credentials.yaml
   ```

2. Edit `secrets/harbor/harbor-credentials.yaml` with your actual passwords:
   ```bash
   nano secrets/harbor/harbor-credentials.yaml
   ```

3. Apply the secret:
   ```bash
   kubectl apply -f secrets/harbor/harbor-credentials.yaml
   ```

## Important

- The `.env` file and `harbor-credentials.yaml` (without .example) are gitignored
- Never commit actual passwords to git
- Change default passwords in production
