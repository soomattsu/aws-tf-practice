moved {
  from = aws_cloudwatch_log_group.hello
  to   = module.ecs_service.aws_cloudwatch_log_group.hello
}

moved {
  from = aws_ecs_task_definition.hello
  to   = module.ecs_service.aws_ecs_task_definition.hello
}

moved {
  from = aws_ecs_service.hello
  to   = module.ecs_service.aws_ecs_service.hello
}

moved {
  from = aws_iam_role.ecs_task_execution
  to   = module.ecs_service.aws_iam_role.ecs_task_execution
}

moved {
  from = aws_iam_role_policy_attachment.ecs_task_execution
  to   = module.ecs_service.aws_iam_role_policy_attachment.ecs_task_execution
}

moved {
  from = aws_security_group.ecs_task
  to   = module.ecs_service.aws_security_group.ecs_task
}

moved {
  from = aws_vpc_security_group_egress_rule.ecs_task_all
  to   = module.ecs_service.aws_vpc_security_group_egress_rule.ecs_task_all
}

moved {
  from = aws_vpc_security_group_ingress_rule.ecs_taks_from_alb
  to   = module.ecs_service.aws_vpc_security_group_ingress_rule.ecs_taks_from_alb
}
