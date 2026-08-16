resource "aws_cloudwatch_log_group" "hello" {
  name              = "/ecs/tf-practice-hello"
  retention_in_days = 1
}

resource "aws_ecs_cluster" "main" {
  name = "tf-practice"
}

resource "aws_ecs_task_definition" "hello" {
  family                   = "tf-practice-hello"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "hello"
      image     = "public.ecr.aws/docker/library/httpd:2.4"
      essential = true
      portMappings = [
        { containerPort = 80, protocol = "tcp" }
      ]
      entryPoint = ["sh", "-c"]
      command = [
        "/bin/sh -c \"echo '<html><body><h1>Hello World from Fargate</h1></body></html>' > /usr/local/apache2/htdocs/index.html && httpd-foreground\""
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.hello.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "hello" {
  name            = "tf-practice-hello"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.hello.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  # 配下のTaskのENI IPをTGに登録するのに加え、LBと連携したライフサイクル管理が行われるようになる
  # - Taskデプロイ時、LBノードによるヘルスチェック（定義はTG側）の結果を参照するようにする
  # - Task終了時、TGへderegisterを呼んでLBノードからの新規接続を停止->deregistration_delayの間待機して既存の接続をdrainする
  load_balancer {
    target_group_arn = aws_lb_target_group.hello.arn
    container_name   = "hello"
    container_port   = 80
  }

  # LBと紐づかないTGを参照してECS Serviceを作るとエラー
  # LB-TGの紐づけを規定するのはlistenerなので、TGを参照するECS Serviceの作成時は、listenerも必要になる
  depends_on = [aws_lb_listener.http]
}
