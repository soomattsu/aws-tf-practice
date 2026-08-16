# ALB用SG（Terraformから作成したSGには、デフォルトのegress全許可は含まれないので、明示的Egressが必要）
resource "aws_security_group" "alb" {
  name        = "tf-practice-alb"
  description = "ALB ingress from Internet"
  vpc_id      = local.vpc_id
  tags = {
    Name = "tf-practice-alb-sg"
  }
}

# port:80への全TCP通信を許可
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# 全egressを許可
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ECS Task用SG。
resource "aws_security_group" "ecs_task" {
  name        = "tf-practice-ecs-task"
  description = "Fargate Task"
  vpc_id      = local.vpc_id
  tags = {
    Name = "tf-practice-ecs-task-sg"
  }
}

# 全egressを許可
resource "aws_vpc_security_group_egress_rule" "ecs_task_all" {
  security_group_id = aws_security_group.ecs_task.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_taks_from_alb" {
  security_group_id = aws_security_group.ecs_task.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  # ALBのSGを参照することで、送信元をALBに固定する（cidr指定と排他）
  referenced_security_group_id = aws_security_group.alb.id
}
