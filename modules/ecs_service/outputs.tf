output "ecs_task_security_group_id" {
  description = "Aurora用SG ruleがingress元として参照するためのECS TaskのSG ID"
  value       = aws_security_group.ecs_task.id
}

output "service_arn" {
  description = "GitHub Actions用CDロールが、ECS更新の対象として参照するためのサービスARN"
  value       = aws_ecs_service.main.arn
}

output "task_execution_role_arn" {
  description = "GitHub Actions用CDロールが、新規作成するTask定義のTask実行ロールとして指定するためのARN"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "service_name" {
  description = "CodeDeployのDeploymentGroupが、対象のECS Serviceとして参照するための名前"
  value       = aws_ecs_service.main.name
}
