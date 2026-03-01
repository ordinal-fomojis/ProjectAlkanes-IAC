# Shovel Infrastructure

Infrastructure as code and Kubernetes configuration for [Shovel](https://shovel.space), a platform for minting Alkane and BRC20 tokens on the Bitcoin blockchain.

## Related Repositories

- [Frontend (NextJS)](https://github.com/ordinal-fomojis/ProjectAlkanes-FE)
- [Backend (Express/MongoDB)](https://github.com/ordinal-fomojis/ProjectAlkanes-BE)
- [Cron Jobs (Azure Functions)](https://github.com/ordinal-fomojis/ProjectAlkanes-Jobs)

## Overview

This repository contains:

- **Terraform** - Azure cloud infrastructure provisioning
- **Kubernetes/Helm** - Application deployment and configuration
- **ArgoCD** - GitOps-based continuous deployment
- **Scripts** - Helper scripts for common operations

## Architecture

### Cloud Infrastructure (Azure)

- **AKS** - Kubernetes cluster with autoscaling (1-10 nodes)
- **ACR** - Container registry for Docker images
- **Function Apps** - Serverless functions for prod/nonprod environments
- **Key Vault** - Secrets management (dotenv private keys)
- **Application Insights** - Monitoring and telemetry
- **Log Analytics** - Centralized logging
- **Storage Account** - Function app blob storage

### Kubernetes

The cluster runs several environments of the backend service (prod, dev, stage, mock, testnet) using an app-of-apps pattern with ArgoCD.

Key components:
- NGINX Gateway Fabric for ingress with automatic TLS via cert-manager
- Horizontal Pod Autoscaler per environment
- Let's Encrypt certificates for `*.shovel.space`

## CI/CD Workflows

Infrastructure provisioning and cluster bootstrapping are handled via GitHub Actions.

### Deploy Terraform

**Trigger:** Pull requests to `main` or manual dispatch

- On PR: Runs `terraform plan` and posts the plan to the PR summary
- On merge to `main`: Automatically applies changes to production
- Manual dispatch: Can target a specific environment ID for non-prod deployments

### Deploy ArgoCD

**Trigger:** Manual dispatch only

Bootstraps the Kubernetes cluster with:
- Gateway API CRDs
- Cluster secrets (GitHub PAT, dotenv private keys)
- ArgoCD installation
- Root application for GitOps

Also configures DNS records in Vercel to point to the cluster's load balancer.

### Destroy

**Trigger:** Manual dispatch only

Destroys non-production environments. Requires an environment ID (cannot destroy prod).

## GitHub Actions Configuration

The workflows require these secrets and variables in GitHub:

**Variables:**
- `AZURE_CLIENT_ID` - Service principal client ID
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
- `AZURE_TENANT_ID` - Azure tenant ID

**Secrets:**
- `ALKANES_IAC_PAT` - GitHub PAT for ArgoCD to access this repo
- `SHOVEL_DOTENV_PRIVATE_KEY_PROD` - Production dotenv encryption key
- `SHOVEL_DOTENV_PRIVATE_KEY_NONPROD` - Non-production dotenv encryption key
- `SHOVEL_VERCEL_TOKEN` - Vercel API token for DNS management

## Local Development

For local testing or debugging, you can run the scripts directly.

### Prerequisites

- Azure CLI (`az`)
- Terraform
- kubectl
- Node.js
- Access to the `fomojis` Azure subscription

### Usage

```bash
npm install

# Terraform
npm run tf-init           # Initialize for production
npm run tf-init <env-id>  # Initialize for a specific environment
npm run tf-plan           # Review changes
npm run tf-apply          # Apply changes

# Kubernetes
npm run kubectl-init      # Get kubectl credentials
npm run pw                # Get ArgoCD admin password
npm run setup-dns         # Update DNS (requires VERCEL_TOKEN, DOMAIN, TEAM_SLUG)
```

ArgoCD UI is available at https://argocd.shovel.space

## Project Structure

```
.github/workflows/   # CI/CD pipelines
  deploy-terraform.yaml  # Plan on PR, apply on merge
  deploy-argocd.yaml     # Bootstrap cluster with ArgoCD
  destroy.yaml           # Tear down non-prod environments

terraform/           # Azure infrastructure
  main.tf            # Resource group, key vault, app insights
  aks.tf             # Kubernetes cluster and container registry
  function-app.tf    # Serverless functions
  variables.tf       # Input variables
  outputs.tf         # Terraform outputs

kubernetes/          # Helm charts and k8s manifests
  root/              # App-of-apps root chart
  argocd/            # ArgoCD installation (Kustomize)
  cluster-config/    # Namespaces and secrets
  shovel-be/         # Backend deployment chart

scripts/             # Helper scripts for local use
  tf-init.sh         # Initialize Terraform
  tf-plan.sh         # Plan infrastructure changes
  tf-apply.sh        # Apply infrastructure changes
  kubectl-init.sh    # Configure kubectl credentials
  setup-dns.ts       # Update Vercel DNS records
```

## Environments

The backend supports multiple environments, configured in `kubernetes/shovel-be/values.yaml`:

| Environment | Subdomain | Description |
|-------------|-----------|-------------|
| prod | api.shovel.space | Production |
| dev | dev.api.shovel.space | Development |
| stage | stage.api.shovel.space | Staging |
| mock | mock.api.shovel.space | Mock data |
| testnet | testnet.api.shovel.space | Bitcoin testnet |

Enable or disable environments by setting `enabled: true/false` in the values file.

## Deployment

### Infrastructure Changes

1. Create a PR with your Terraform changes
2. Review the plan in the PR summary
3. Merge to `main` - changes are applied automatically

### Application Deployments

Application deployments are managed through ArgoCD, which syncs from this repo automatically.

To deploy a new backend version:

1. Update the `tag` in `kubernetes/shovel-be/values.yaml` with the new image tag
2. Commit and push to `main`
3. ArgoCD will sync and deploy the changes

The backend images are built and pushed to ACR by the CI pipeline in the backend repository.

## Secrets

Secrets are managed via:
- **Azure Key Vault** - For function apps (dotenv private keys)
- **Kubernetes Secrets** - For the backend pods (created via cluster-config chart)

The `DOTENV_PRIVATE_KEY_*` environment variables are used to decrypt encrypted environment files at runtime.

## Terraform State

Terraform state is stored remotely in Azure Blob Storage:
- Storage Account: `fomojisterraform`
- Container: `tfstate`
- Resource Group: `iac`

Each environment has its own state file (e.g., `shovel.tfstate`, `shovel-dev.tfstate`).
