variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "profile" {
  type = string
}

variable "terraform_exec_role_arn" {
  type = string
}

variable "state_bucket" {
  type = string
}

variable "image_tags" {
  description = "ECSサービスごとのコンテナイメージタグ"
  type        = map(string)
}

variable "allowed_ingress_cidrs" {
  description = "ALBへのアクセスを許可するIPリスト"
  type        = list(string)
}

variable "datadog_api_key" {
  type      = string
  sensitive = true
}
