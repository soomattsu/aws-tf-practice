resource "aws_cloudwatch_log_group" "main" {
  name              = "/ecs/${var.name_prefix}-${var.service_name}"
  retention_in_days = 1
}

locals {
  container_definitions = [
    for name, c in var.containers : merge(
      {
        name      = name
        image     = c.image
        essential = c.essential
        # Task外へportを公開する際に必要（Task内でlocalhostでのみアクセスされるportについては定義不要）
        portMappings = c.port != null ? [{
          containerPort = c.port,
          protocol      = "tcp",
          # AWS側のデフォルト値補完によってprior stateとconfig間に差分が生じ、revisionが増殖するのを予防する
          hostPort = c.port
        }] : []
        dockerLabels = c.docker_labels
        environment  = [for k, v in c.environment : { name = k, value = v }]
        secrets = [
          for k, v in c.secrets : {
            name      = k
            valueFrom = v.json_key != null ? "${v.arn}:${v.json_key}::" : v.arn
          }
        ]

        /*
          コンテナログ（stdout/stderr）をどこに・どのように転送するかを設定

          共通の仕組み
          1. micro-VM上のコンテナランタイムが匿名pipeを2つ作成し、子プロセスとして起動するTask内の各コンテナがpipeのfdを継承する
          2. Taskコンテナのstdout/stderrへの書き込みが、それぞれのpipeを介してコンテナランタイムへ届く
          3. コンテナランタイムが各pipeのread fdから各Taskコンテナの出力を読み込み、logDriverへ渡す

          logDriver設定の実体は「どのLoggerインターフェース実装を利用するか」の指定。Fargateでは以下3つが有効。
          - awslogs -> CloudWatchへの転送用
          - splunk -> Splunkへの転送用
          - awsfirelens -> ユーザー定義のlog-router sidecar(fluentd/fluent bit)を介した、任意の宛先への転送用
            - 糖衣構文であり、この場合のlogDriverの実体はコンテナランタイム側fluentd
            - 「ランタイム側fluentd -> (unix domain socket) -> Task側fluentd/fluent-bit」という流れ
              - logDriver(ランタイム側ns)/log-router(Task側ns間)で、socketファイルをbind mountによって共有している
        */
        logConfiguration = {
          # ログ設定未定義のコンテナでは、デフォルトの転送先としてCloudWatch LogGroupを指定する
          logDriver = c.log_configuration == null ? "awslogs" : c.log_configuration.driver
          options = c.log_configuration == null ? tomap({
            "awslogs-group"         = aws_cloudwatch_log_group.main.name
            "awslogs-region"        = var.region
            "awslogs-stream-prefix" = "ecs"
          }) : c.log_configuration.options
          secretOptions = c.log_configuration == null ? [] : [
            for k, v in c.log_configuration.secret_options : { name = k, valueFrom = v }
          ]
        }

        # AWS側のデフォルト値補完によってprior stateとconfig間に差分が生じ、revisionが増殖するのを予防する
        mountPoints    = []
        systemControls = []
        volumesFrom    = []

        # log-router用のsidecarコンテナのみが持つキー群
        # 条件trueの場合、TerraformのAWSプロバイダはJSON内の値がnullなフィールドを無視するので、結果的に未定義扱いになる
        firelensConfiguration = c.firelens_configuration == null ? null : {
          type    = c.firelens_configuration.type
          options = c.firelens_configuration.options
        }
        # AWS側のデフォルト値補完によってprior stateとconfig間に差分が生じ、revisionが増殖するのを予防する
        user = c.firelens_configuration == null ? null : "0"
      }
    )
  ]
}

resource "aws_ecs_task_definition" "main" {
  family                   = "${var.name_prefix}-${var.service_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "1024"
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

  # ECS Serviceが何によって・どのようにデプロイされるかを規定する（Service作成後に変更可能）
  deployment_controller {
    type = var.deployment_controller
  }

  # 配下のTaskのENI IPをTGに登録するのに加え、LBと連携したライフサイクル管理が行われるようになる
  # - Taskデプロイ時、LBノードによるヘルスチェック（定義はTG側）の結果を参照するようにする
  # - Task終了時、TGへderegisterを呼んでLBノードからの新規接続を停止->deregistration_delayの間待機して既存の接続をdrainする
  load_balancer {
    target_group_arn = var.alb_integration.target_group_arn
    container_name   = var.alb_integration.target_container_name
    container_port   = var.containers[var.alb_integration.target_container_name].port
  }

  # lifecycle.ignore_changes: 指定した属性について、prior state(≒実リソース) vs config(HCL評価結果)の差分検知を抑制し、prior stateを正として扱う
  #
  # task_definition
  # - ここでは「"serviceが指すtask_defのARN"については、prior stateを正とする」という意味
  # - 「どのimageをdeployするか＝serviceがどのtask_defを指すか」の定義はGHAの責務になるので、service/task_defの参照関係についてはdriftを許容する
  # - 備考：GHAが"ECS Taskのimage更新"のために行う処理
  #   1. 最新のtask_defを元に、imageのみ差し替えた新規task_def(tf管理外)を作成
  #   2. 1で作成したtask_defを指すように、ECS Serviceを更新
  # - 注意：Terraformによるtask_defリソース自体の変更（ex. cpu/mem）は、apply実行時ではなく、次回のGHA経由deploy時に環境に反映される！
  #   - 新しいrevisionのtask_defは作成されるが、それがserviceから参照されるのは、GHAがUpdateServiceをkickしたタイミング
  #
  # load_balancer
  # 以下の理由から、同様にignore_changesが必要
  #   1. deployment_controller=CODE_DEPLOYなServiceに対してecs:UpdateServiceを呼ぶ場合、load_balancerは無効な引数
  #     -> load_balancer引数に差分がある状態で、当該Serviceリソースのapplyを実行するとAWS側で必ずエラーになる
  #   2. CodeDeployでのB/G完了後、service.loadBalancersは切り替え後のTGを指し続けるので、prior stateとconfigが必然的にズレる
  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer
    ]
  }
}
