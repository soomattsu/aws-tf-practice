resource "aws_security_group" "ecs_task" {
  name        = "${var.name_prefix}-${var.service_name}-ecs-task"
  description = "Fargate Task"
  vpc_id      = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-${var.service_name}-ecs-task-sg"
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
  from_port         = var.container_port
  to_port           = var.container_port
  ip_protocol       = "tcp"
  # ALBのSGを参照することで、送信元をALBに固定する（cidr指定と排他）
  referenced_security_group_id = var.alb_security_group_id
}
