locals {
  container_port = 80
}

resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.name_prefix}-${var.service_name}"
  retention_in_days = 1
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name_prefix}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = var.service_name
      image     = "public.ecr.aws/docker/library/httpd:2.4"
      essential = true
      portMappings = [
        { containerPort = local.container_port, protocol = "tcp" }
      ]
      entryPoint = ["sh", "-c"]
      command = [
        "/bin/sh -c \"echo '<html><body><h1>Hello World from Fargate</h1></body></html>' > /usr/local/apache2/htdocs/index.html && httpd-foreground\""
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "main" {
  name            = "${var.name_prefix}-${var.service_name}"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  # 配下のTaskのENI IPをTGに登録するのに加え、LBと連携したライフサイクル管理が行われるようになる
  # - Taskデプロイ時、LBノードによるヘルスチェック（定義はTG側）の結果を参照するようにする
  # - Task終了時、TGへderegisterを呼んでLBノードからの新規接続を停止->deregistration_delayの間待機して既存の接続をdrainする
  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = var.service_name
    container_port   = local.container_port
  }
}
