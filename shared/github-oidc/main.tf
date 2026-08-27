# IdPとしてGitHub Actionsを信頼する
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# 条件を満たしたOIDCトークン（JWT）を持つGitHub Actions経由のrunnerに、assume roleを許可する
data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${var.github_oidc_sub}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "GitHubActionsEcrPushRole"
  assume_role_policy = data.aws_iam_policy_document.trust.json
  description        = "Role to be assumed by GitHub Actions runner in order to push image into ECR"
}

data "aws_caller_identity" "current" {}

locals {
  ecr_repository_prefix = "tf-practice"
}

data "aws_iam_policy_document" "ecr_push" {
  # ECR認証トークン取得
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # ECRへのimage upload
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = ["arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${local.ecr_repository_prefix}/*"]
  }
}

# 自作のインラインポリシーをGHA用ロールに埋め込む
# 管理ポリシー（AWS/自作）をattachする場合はaws_iam_role_policy_attachmentを使う
# 使い分け：他のプリンシパルに付き得るポリシーは管理ポリシー、特定プリンシパルにしか付かないならインラインポリシー
resource "aws_iam_role_policy" "ecr_push" {
  name   = "ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ecr_push.json
}
