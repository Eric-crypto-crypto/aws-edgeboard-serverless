locals {
  state_bucket = "edgeboard-tfstate-181851924026"
  oidc_host    = "token.actions.githubusercontent.com"

  # GitHub immutable subject format: <owner>@<owner_id>/<repo>@<repo_id>
  # Look it up with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub
  github_sub_prefix = "repo:Eric-crypto-crypto@181318956/aws-edgeboard-serverless@1435075365"
}

# ===== 1. OIDC identity provider: lets AWS trust tokens issued by GitHub =====
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ===== 2. Plan role: read-only, usable by any PR =====
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # The token must be issued for AWS STS
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # The token must come from a pull_request event in this repo
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.github_sub_prefix}:pull_request"]
    }
  }
}

resource "aws_iam_role" "plan" {
  name                 = "edgeboard-github-plan"
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600 # Temporary credentials last at most 1 hour
}

# AWS managed read-only policy: can inspect resources but change nothing
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# The only write permission: plan must create and delete the state lock file
data "aws_iam_policy_document" "plan_state_lock" {
  statement {
    sid       = "StateLockFile"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${local.state_bucket}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "plan_state_lock" {
  name   = "state-lock"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state_lock.json
}

# ===== 3. Apply role: only jobs running in the dev environment =====
data "aws_iam_policy_document" "apply_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Note: once a job sets an environment, sub becomes ...:environment:<name>
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.github_sub_prefix}:environment:dev"]
    }
  }
}

resource "aws_iam_role" "apply" {
  name                 = "edgeboard-github-apply-dev"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "apply_admin" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
