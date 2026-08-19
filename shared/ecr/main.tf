locals {
  name_prefix = "tf-practice"
  services    = ["document-api", "post-api"]
}

resource "aws_ecr_repository" "main" {
  for_each = toset(local.services)

  name = "${local.name_prefix}/${each.value}"

  force_delete = true

  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# リソースベースポリシーを付与し、指定アカウント上のECSコンテナエージェントによるimage pullを許可しておく
data "aws_iam_policy_document" "cross_account_pull" {
  statement {
    sid    = "AllowWorkloadAccountPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [for id in var.workload_account_ids : "arn:aws:iam::${id}:root"]
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }
}

resource "aws_ecr_repository_policy" "main" {
  # for_eachで作成した既存リソースを参照すると、型はmap(object)になる
  # - key = 元のfor_eachのキー
  # - value = 個々のaws_ecr_repositoryリソースを表すobject
  for_each = aws_ecr_repository.main

  repository = each.value.name
  policy     = data.aws_iam_policy_document.cross_account_pull.json
}
