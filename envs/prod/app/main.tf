# ECS ClusterとALB(w/ listener, TG, SG)を作成した後、module:ecs_serviceを呼ぶ

data "terraform_remote_state" "main" {
  for_each = local.remote_states

  backend = "s3"
  config = {
    bucket  = var.state_bucket
    key     = each.value
    region  = var.region
    profile = var.profile
  }
}

locals {
  remote_states = {
    network = "envs/prod/network/terraform.tfstate"
    ecr     = "shared/ecr/terraform.tfstate"
    db      = "envs/prod/db/terraform.tfstate"
  }

  name_prefix         = "tf-practice"
  service_name        = "document"
  container_port      = 8080
  vpc_id              = data.terraform_remote_state.main["network"].outputs.vpc_id
  public_subnet_ids   = data.terraform_remote_state.main["network"].outputs.public_subnet_ids
  private_subnet_ids  = data.terraform_remote_state.main["network"].outputs.private_subnet_ids
  ecr_repository_urls = data.terraform_remote_state.main["ecr"].outputs.repository_urls
}

module "ecs_service" {
  source = "../../../modules/ecs_service"

  region                = var.region
  name_prefix           = local.name_prefix
  service_name          = local.service_name
  container_image       = "${local.ecr_repository_urls["document-api"]}:${var.image_tag}"
  container_port        = local.container_port
  vpc_id                = local.vpc_id
  private_subnet_ids    = local.private_subnet_ids
  ecs_cluster_id        = aws_ecs_cluster.main.id
  alb_target_group_arn  = aws_lb_target_group.main.arn
  alb_security_group_id = aws_security_group.alb.id

  # LBと紐づかないTGを参照してECS Serviceを作るとエラー
  # LB-TGの紐づけを規定するのはlistenerなので、TGを参照するECS Serviceの作成時は、listenerも必要になる
  depends_on = [aws_lb_listener.http]
}

resource "aws_ecs_cluster" "main" {
  name = local.name_prefix
}

# ELBのリソース構造
# - ELB --has-> Listener --forward-> TargetGroup
# - TargetGroupは独立したトップレベルリソースであり、LB:TGは多対多になる
# - Listenerのforwardアクションのみによって、LBとTGが紐づく

resource "aws_lb" "main" {
  name               = local.name_prefix
  load_balancer_type = "application"
  internal           = false
  subnets            = local.public_subnet_ids # ALBなので、複数AZが必要
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "main" {
  name = "${local.name_prefix}-${local.service_name}"
  # ターゲットをENIのIPアドレスで指定。ECS Taskのnetwork_mode="awspvc"（=Fargate）では必ずこれ
  # （その他インスタンスID, Lambda, ALBなど）
  target_type = "ip"
  port        = 80 # APIコールの引数としてrequriedだが、実際はECSによるターゲット登録時に上書きされる
  protocol    = "HTTP"
  vpc_id      = local.vpc_id

  health_check {
    path                = "/healthz"
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
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ALB用SG（Terraformから作成したSGには、デフォルトのegress全許可は含まれないので、明示的Egressが必要）
resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "ALB ingress from Internet"
  vpc_id      = local.vpc_id
  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

# port:80への全TCP通信を許可
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  for_each = toset(var.allowed_ingress_cidrs)

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
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

# ECS TaskからAuroraを呼び出すために、AuroraのSGへ付与するIngressルール
# AuroraのSG自体はDB側stateで管理しており、循環参照を避けるために呼び出し側で独立にルール定義する
resource "aws_vpc_security_group_ingress_rule" "aurora_from_ecs_task" {
  security_group_id            = data.terraform_remote_state.main["db"].outputs.security_group_id
  from_port                    = data.terraform_remote_state.main["db"].outputs.cluster_port
  to_port                      = data.terraform_remote_state.main["db"].outputs.cluster_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs_service.ecs_task_security_group_id
}
