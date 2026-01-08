# Harbor Secrets

This directory contains templates and scripts for managing Harbor secrets.

## Files

- `.env.example` - Template for Harbor credentials (copy to `.env`)

## Setup

1. Copy the example file:
   ```bash
   cp secrets/harbor/.env.example secrets/harbor/.env
   ```

2. Edit `.env` with your actual passwords:
   ```bash
   nano secrets/harbor/.env
   ```

3. Create the Kubernetes secret:
   ```bash
   ./scripts/create-harbor-secrets.sh
   ```

## Important

- The `.env` file is gitignored and will never be committed
- Never commit actual passwords to git
- Change default passwords in production
