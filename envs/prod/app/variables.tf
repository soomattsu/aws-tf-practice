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
