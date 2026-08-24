resource "aws_security_group" "ecs_task" {
  name_prefix = "${var.name_prefix}-${var.service_name}-ecs-task-"
  description = "Fargate Task"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-${var.service_name}-ecs-task-sg"
  }

  # 変更無し or in-place updateされる既存リソースから依存されている場合、"destroy and then create replacement"は失敗する
  # - 最初のdestroy時点で既存リソースからの参照が残っているため、DependencyViolationエラー
  # - AがBに依存しており、A,B両方destroyされる場合にのみ、destroy A -> destroy Bの実行順序が保証される
  # ここでは、ingress_rule.aurora_from_ecs_taskからの参照がdestroyを阻害するので、先に新SGを作って依存を張り替えた後に削除する必要がある
  lifecycle {
    create_before_destroy = true
  }
}

# 全egressを許可
resource "aws_vpc_security_group_egress_rule" "ecs_task_all" {
  security_group_id = aws_security_group.ecs_task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_task_from_alb" {
  security_group_id = aws_security_group.ecs_task.id
  from_port         = var.containers[var.alb_integration.target_container_name].port
  to_port           = var.containers[var.alb_integration.target_container_name].port
  ip_protocol       = "tcp"
  # ALBのSGを参照することで、送信元をALBに固定する（cidr指定と排他）
  referenced_security_group_id = var.alb_integration.security_group_id
}
