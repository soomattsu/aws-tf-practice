data "aws_iam_policy_document" "codedeploy_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codedeploy.amazonaws.com"]
    }
  }
}

# CodeDeployがECS/ELBのAPIを利用するためのロール
resource "aws_iam_role" "codedeploy" {
  name               = "${local.name_prefix}-codedeploy"
  assume_role_policy = data.aws_iam_policy_document.codedeploy_trust.json
  description        = "Role assumed by CodeDeploy to shift traffic between ECS task sets"
}

# ECS B/G deploy用のAWS管理ポリシー（ECS・ALB操作）をロールへ紐づけ
resource "aws_iam_role_policy_attachment" "codedeploy_ecs" {
  role       = aws_iam_role.codedeploy.name
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeDeployRoleForECS"
}

# CodeDeploy application(名前空間)の定義
resource "aws_codedeploy_app" "main" {
  for_each = local.bluegreen_services

  name             = "${local.name_prefix}-${each.key}"
  compute_platform = "ECS"
}

# CodeDeploy deployment group(設定本体)の定義
resource "aws_codedeploy_deployment_group" "main" {
  for_each = local.bluegreen_services

  app_name              = aws_codedeploy_app.main[each.key].name
  deployment_group_name = "${local.name_prefix}-${each.key}"
  service_role_arn      = aws_iam_role.codedeploy.arn

  # trafficの10%をgreenへ流して5分待機 -> 残り90%を一括でgreenへ切り替え
  # 待機中の5分間はblue/greenに並列でtrafficが流れる
  deployment_config_name = "CodeDeployDefault.ECSCanary10Percent5Minutes"

  # LBのtrafficを制御してB/Gを実行する旨の定義
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL" # defaultはWITHOUT_*
    deployment_type   = "BLUE_GREEN"           # defaultはIN_PLACE
  }

  blue_green_deployment_config {
    # 新verがデプロイ完了(ready)した時の挙動を設定
    deployment_ready_option {
      # 旧verから新verへのtraffic切り替えをいつ行うか（自動 or 手動承認）
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    # B/G deploy完了（trafficが100%移行）時に旧verをどう扱うかを設定
    terminate_blue_instances_on_deployment_success {
      action = "TERMINATE"
      # 終了までのバッファ時間 -> この間なら、ロールバックは"listenerのTG切り替え"だけで完了する
      termination_wait_time_in_minutes = 5
    }
  }

  auto_rollback_configuration {
    enabled = true
    # 新verがhealthyにならない or コンソール/APIからデプロイ中断した際に、自動的に旧verへ戻す
    events = [
      "DEPLOYMENT_FAILURE",
      "DEPLOYMENT_STOP_ON_REQUEST"
    ]
  }

  ecs_service {
    cluster_name = aws_ecs_cluster.main.name
    service_name = module.ecs_service[each.key].service_name
  }

  load_balancer_info {
    target_group_pair_info {
      # 本番trafficのlistener
      prod_traffic_route {
        listener_arns = [aws_lb_listener.bluegreen_prod[each.key].arn]
      }
      # 検証用trafficのlistener。切り替え完了前に新verへ到達する経路
      test_traffic_route {
        listener_arns = [aws_lb_listener.bluegreen_test[each.key].arn]
      }
      # 「どちらのTGが本番か」はCodeDeployが動的に判断する
      target_group {
        name = aws_lb_target_group.main["${each.key}-1"].name
      }
      target_group {
        name = aws_lb_target_group.main["${each.key}-2"].name
      }
    }
  }
}
