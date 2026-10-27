# aws-edgeboard-serverless

A full-stack interactive site built on AWS Serverless: visitor counter + guestbook.

**Tech stack**: S3 · CloudFront (OAC) · API Gateway (HTTP API) · Lambda (Python 3.13) · DynamoDB · Route 53 · ACM · Terraform · GitHub Actions (OIDC)

## Repository Structure

```
├── frontend/              # Static pages
├── backend/
│   ├── src/handlers/      # Lambda code
│   └── tests/             # pytest + moto
├── infra/
│   ├── bootstrap/         # Terraform remote state bucket (one-time)
│   ├── modules/           # static_site / api / database
│   └── envs/dev, prod     # Environment entry points
└── .github/workflows/     # CI/CD
```

## Prerequisites

- AWS account: MFA enabled on root; daily sign-in via IAM Identity Center
- Dev environment: GitHub Codespaces (`.devcontainer/` preinstalls AWS CLI v2, Terraform ≥ 1.10, Python 3.13)
- Sign in to AWS: `aws sso login --use-device-code`

## Bootstrap: Terraform Remote State

Terraform state is stored in S3, but that S3 bucket itself must be created first — the classic IaC chicken-and-egg problem.
Solution: `infra/bootstrap/` uses **local state** to create the state bucket separately. It only needs to run once.

```bash
cd infra/bootstrap
terraform init
terraform apply
```

State bucket configuration: versioning, SSE encryption, all public access blocked, HTTPS-only, and `prevent_destroy` to guard against accidental deletion.
Each environment uses S3 native locking (`use_lockfile = true`, Terraform 1.10+) to prevent concurrent writes.
