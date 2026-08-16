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

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
