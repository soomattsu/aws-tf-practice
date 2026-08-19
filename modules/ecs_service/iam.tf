data "aws_iam_policy_document" "ecs_task_execution_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ECSのタスク実行ロール
# ECSコンテナエージェント（AWSサービス側）にAssumeされ、CloudWatchロギングとECR image pullに使われる
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.name_prefix}-${var.service_name}-ecs-task-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_trust.json
}

# AWS管理ポリシー or 自作のaws_iam_policyを、任意のロールに紐づける
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_secrets" {
  count = length(var.secret_arns) > 0 ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = var.secret_arns
  }
}

# タスク実行ロールに直接埋め込むインラインポリシーを定義
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  count  = length(var.secret_arns) > 0 ? 1 : 0
  name   = "secrets-access"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_secrets[0].json
}
