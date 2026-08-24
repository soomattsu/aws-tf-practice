resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.name_prefix}-${var.service_name}"
  retention_in_days = 1
}

locals {
  container_definitions = [
    for name, c in var.containers : {
      name      = name
      image     = c.image
      essential = c.essential
      # Task外へportを公開する際に必要（Task内でlocalhostでのみアクセスされるportについては定義不要）
      portMappings = c.port != null ? [{ containerPort = c.port, protocol = "tcp" }] : []
      environment  = [for k, v in c.environment : { name = k, value = v }]
      secrets = [
        for k, v in c.secrets : {
          name      = k
          valueFrom = v.json_key != null ? "${v.arn}:${v.json_key}::" : v.arn
        }
      ]
      # コンテナログ（stdout/stderr）をどこに・どのように転送するかを設定
      logConfiguration = {
        # 共通の仕組み
        # 1. micro-VM上のコンテナランタイムが匿名pipeを2つ作成し、子プロセスとして起動するTask内の各コンテナがpipeのfdを継承する
        # 2. Taskコンテナのstdout/stderrへの書き込みが、それぞれのpipeを介してコンテナランタイムへ届く
        # 3. コンテナランタイムが各pipeのread fdから各Taskコンテナの出力を読み込み、logDriverへ渡す

        # logDriver設定の実体は「どのLoggerインターフェース実装を利用するか」の指定。Fargateでは以下3つが有効。
        # - awslogs -> CloudWatchへの転送用
        # - splunk -> Splunkへの転送用
        # - awsfirelens -> ユーザー定義のlog-router sidecar(fluentd/fluent bit)を介した、任意の宛先への転送用
        #   - 糖衣構文であり、この場合のlogDriverの実体はコンテナランタイム側fluentd
        #   - 「ランタイム側fluentd -> (unix domain socket) -> Task側fluentd/fluent-bit」という流れ
        #     - logDriver(ランタイム側ns)/log-router(Task側ns間)で、socketファイルをbind mountによって共有している
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.main.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ]
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name_prefix}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode(local.container_definitions)
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
    target_group_arn = var.alb_integration.target_group_arn
    container_name   = var.alb_integration.target_container_name
    container_port   = var.containers[var.alb_integration.target_container_name].port
  }
}
