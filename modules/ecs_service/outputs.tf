output "ecs_task_security_group_id" {
  description = "Aurora用SG ruleがingress元として参照するためのECS TaskのSG ID"
  value       = aws_security_group.ecs_task.id
}
