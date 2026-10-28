# aws-edgeboard-serverless

A full-stack interactive site built on AWS Serverless: visitor counter + guestbook.

**Live demo**: https://dev.edgeboard.click

**Tech stack**: S3 · CloudFront (OAC) · API Gateway (HTTP API) · Lambda (Python 3.13) · DynamoDB · Route 53 · ACM · Terraform · GitHub Actions (OIDC)

## Architecture

```
Browser ──HTTPS──> CloudFront (dev.edgeboard.click)
                    ├── /api/*  ──> API Gateway (HTTP API) ──> Lambda ×3 ──> DynamoDB
                    └── /*      ──> S3 (private, OAC)
```

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| API entry point | CloudFront `/api/*` forwarding | Frontend and API share one origin, so no CORS needed; the API also gets edge TLS and Shield Standard |
| API type | HTTP API | ~70% cheaper than REST API, with lower latency |
| Counter | DynamoDB `ADD` atomic update | Tested with 20 concurrent requests: read-modify-write recorded only 15, `ADD` recorded all 20 |
| Message pagination | Query + cursor (`LastEvaluatedKey`) | No Scan; the cursor's partition is validated to prevent tampering |
| Lambda | Dedicated IAM role per function, arm64 | Least privilege; arm64 is ~20% cheaper than x86 |
| S3 access | Private bucket + OAC + `SourceArn` | Only this distribution can read the bucket, preventing the confused deputy problem |
| Certificate | ACM (us-east-1) + DNS validation | CloudFront only reads certificates from us-east-1; DNS validation enables automatic renewal |

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

## Measured Results

| Metric | Value |
|---|---|
| Lambda cold start Init (arm64 / 256 MB) | ~650 ms |
| Warm API end-to-end latency | ~30 ms (of which ~9 ms is API Gateway itself) |
| Throttling | rate 20 / burst 50; excess requests return 429 |

## Known Limitations & Future Improvements

- The raw API Gateway endpoint (`execute-api`) is still publicly reachable, allowing CloudFront to be bypassed. Improvement: have CloudFront inject a secret header and validate it in the backend.
- The visitor counter increments on every page refresh. Improvement: count unique visitors using an IP hash + TTL.
