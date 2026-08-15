variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "profile" {
  description = "assume_roleの呼び出し元"
  type        = string
}

variable "terraform_exec_role_arn" {
  description = "assume_roleの呼び出し先"
  type        = string
}
