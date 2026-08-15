data "aws_caller_identity" "current" {}

resource "aws_ssm_parameter" "smoke" {
  name  = "/tf-practice/day3/cross-account-smoke"
  type  = "String"
  value = "ok"
}
