locals {
  bucket_name = "${var.name_prefix}-${var.bucket_suffix}"
}

resource "aws_s3_bucket" "handson" {
  bucket = local.bucket_name
}

resource "aws_ssm_parameter" "handson" {
  name  = "/${var.name_prefix}/greeting"
  type  = "String"
  value = "hello"
}
