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
  vpc_id              = data.terraform_remote_state.main["network"].outputs.vpc_id
  public_subnet_ids   = data.terraform_remote_state.main["network"].outputs.public_subnet_ids
  private_subnet_ids  = data.terraform_remote_state.main["network"].outputs.private_subnet_ids
  ecr_repository_urls = data.terraform_remote_state.main["ecr"].outputs.repository_urls

  services = {
    post = {
      containers = {
        post = {
          image = "${local.ecr_repository_urls["post-api"]}:${var.image_tags["post"]}"
          port  = 8080
          environment = {
            MYSQL_HOST     = data.terraform_remote_state.main["db"].outputs.cluster_endpoint
            MYSQL_PORT     = tostring(data.terraform_remote_state.main["db"].outputs.cluster_port)
            MYSQL_DATABASE = data.terraform_remote_state.main["db"].outputs.database_name
          }
          secrets = {
            # RDSがSecrets Manager上に生成したシークレットを参照
            MYSQL_USER = {
              arn      = data.terraform_remote_state.main["db"].outputs.master_user_secret_arn
              json_key = "username"
            }
            MYSQL_PASSWORD = {
              arn      = data.terraform_remote_state.main["db"].outputs.master_user_secret_arn
              json_key = "password"
            }
          }
        }
        datadog-agent = {
          image     = "public.ecr.aws/datadog/agent:latest"
          essential = false
          environment = {
            DD_SITE        = "ap1.datadoghq.com"
            DD_APM_ENABLED = "true"
            ECS_FARGATE    = "true"
          }
          secrets = {
            DD_API_KEY = {
              arn = aws_secretsmanager_secret.datadog_api_key.arn
            }
          }
        }
      }
      need_aurora = true
    }
    document = {
      containers = {
        document = {
          image = "${local.ecr_repository_urls["document-api"]}:${var.image_tags["document"]}"
          port  = 8080
        }
      }
      need_aurora = false
    }
  }
}

module "ecs_service" {
  source = "../../../modules/ecs_service"

  for_each = local.services

  region             = var.region
  name_prefix        = local.name_prefix
  service_name       = each.key
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
  ecs_cluster_id     = aws_ecs_cluster.main.id
  containers         = each.value.containers
  alb_integration = {
    target_group_arn      = aws_lb_target_group.main[each.key].arn
    security_group_id     = aws_security_group.alb.id
    target_container_name = each.key
  }

  # 前提
  # - LBと紐づかないTGを参照してECS Serviceを作るとエラー
  # - LB-TGの紐づけを規定するのはlistener or listener_rule
  # 帰結：TGを参照するECS Serviceの作成は、暗黙的にこれらに依存する
  # - depends_onは静的参照しか許さないので、each.keyを使った動的参照はエラーになる
  depends_on = [aws_lb_listener_rule.http]
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
  # TGは負荷分散先の1単位ごとに作成する。今回は1ALB -> 2ECSの構成なので、ECS毎に作成する
  for_each = local.services

  name = "${local.name_prefix}-${each.key}"
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

  # TG作成→listenerの参照更新→旧TG削除の順序を保証する
  # TGは既存listenerから依存されているため、旧TG削除が先に走ると失敗する
  lifecycle {
    create_before_destroy = true
  }

  deregistration_delay = 30 # デフォルト300秒。destroyの高速化のため
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = 404
    }
  }
}

# ALBとTGの紐づけを規定する
resource "aws_lb_listener_rule" "http" {
  for_each = local.services

  listener_arn = aws_lb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[each.key].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}*"]
    }
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
  for_each                     = { for k, v in local.services : k => v if v.need_aurora }
  security_group_id            = data.terraform_remote_state.main["db"].outputs.security_group_id
  from_port                    = data.terraform_remote_state.main["db"].outputs.cluster_port
  to_port                      = data.terraform_remote_state.main["db"].outputs.cluster_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = module.ecs_service[each.key].ecs_task_security_group_id
}

# datadogのAPI keyをSecrets Managerで管理する
resource "aws_secretsmanager_secret" "datadog_api_key" {
  name                    = "${local.name_prefix}-dd-api-key"
  recovery_window_in_days = 0 # AWS SecretManager側で削除を猶予する日数（tf destroyで消したい場合は0）
}

resource "aws_secretsmanager_secret_version" "datadog_api_key" {
  secret_id     = aws_secretsmanager_secret.datadog_api_key.id
  secret_string = var.datadog_api_key
}
