locals {
  state_bucket     = "edgeboard-tfstate-181851924026"
  oidc_host    = "token.actions.githubusercontent.com"

  # GitHub 不可变 subject 格式：<用户名>@<用户ID>/<仓库名>@<仓库ID>
  # 查询命令：gh api repos/<owner>/<repo>/actions/oidc/customization/sub
  github_sub_prefix = "repo:Eric-crypto-crypto@181318956/aws-edgeboard-serverless@1435075365"
}

# ===== 1. OIDC 身份提供商：让 AWS 信任 GitHub 这个"售票平台" =====
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ===== 2. plan 角色：任何 PR 都可以使用，只读 =====
data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # 票必须是签发给 AWS STS 的
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # 票必须来自本仓库的 PR 事件
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
  max_session_duration = 3600 # 临时凭证最长 1 小时
}

# AWS 托管的只读策略：能查看资源配置，但不能修改任何东西
resource "aws_iam_role_policy_attachment" "plan_readonly" {
  role       = aws_iam_role.plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 唯一的"写"权限：plan 时需要创建和删除 state 锁文件
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

# ===== 3. apply 角色：只有 dev 环境的部署任务可以使用 =====
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

    # 注意：任务指定了 environment 后，sub 的格式是 environment:<名字>
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
