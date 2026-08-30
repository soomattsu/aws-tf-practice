# infra-sharedアカウントのGitHub Actions用ロールからwl-prodアカウントのECSを操作するための、CD用ロールを定義する
# GHA runnerの認証経路
# 1. OIDC -> (AssumeRoleWithWebIdentity) -> infra-shared:github_actions_role_arn
# 2. infra-shared:github_actions_role_arn -> (role chain) -> wl-prod:GitHubActionsEcsDeployRole

data "aws_iam_policy_document" "cd_trust" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
      "sts:TagSession" # aws-actions/configure-aws-credentialsがAssumeRoleする際に同時に呼ばれる
    ]

    principals {
      type        = "AWS"
      identifiers = [var.github_actions_role_arn]
    }
  }
}

resource "aws_iam_role" "cd" {
  name                 = "GitHubActionsEcsDeployRole"
  assume_role_policy   = data.aws_iam_policy_document.cd_trust.json
  max_session_duration = 3600
  description          = "Role assumed by GitHub Actions to update ECS services in this account"
}

data "aws_iam_policy_document" "cd_permission" {
  # 既存task_defの参照 + 新規task_defの登録
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource"
    ]
    resources = ["*"]
  }
  # ECS参照・更新の対象を、自作のserviceに限定
  statement {
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:UpdateService"
    ]
    resources = [for m in module.ecs_service : m.service_arn]
  }
  # task_def作成時のtask実行ロール引数へ渡せる値を、自作のtask実行ロールに限定
  # CDロールは任意の内容のtask_defを使ってserviceを更新できるので、CDが乗っ取られた時の権限昇格を防ぐために、task_defで指定できるロールを限定する必要がある
  # - ex. CDをhack -> AdministratorAccess持ちのtask_defでserviceを更新 -> コンテナ経由でAWSアカウント侵略
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [for m in module.ecs_service : m.task_execution_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# CD用ロールにinline policyを書き込み
resource "aws_iam_role_policy" "cd" {
  name   = "ecs-deploy"
  role   = aws_iam_role.cd.id
  policy = data.aws_iam_policy_document.cd_permission.json
}
