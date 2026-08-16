# ELBのリソース構造
# - ELB --has-> Listener --forward-> TargetGroup
# - TargetGroupは独立したトップレベルリソースであり、LB:TGは多対多になる
# - Listenerのforwardアクションのみによって、LBとTGが紐づく

resource "aws_lb" "main" {
  name               = "tf-practice"
  load_balancer_type = "application"
  internal           = false
  subnets            = local.public_subnet_ids # ALBなので、複数AZが必要
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "hello" {
  name = "tf-practice-hello"
  # ターゲットをENIのIPアドレスで指定。ECS Taskのnetwork_mode="awspvc"（=Fargate）では必ずこれ
  # （その他インスタンスID, Lambda, ALBなど）
  target_type = "ip"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = local.vpc_id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  deregistration_delay = 30 # デフォルト300秒。destroyの高速化のため
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.hello.arn
  }
}
