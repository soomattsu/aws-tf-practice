variable "region" {
  type    = string
  default = "ap-northeast-1"
}

variable "profile" {
  type = string
}

variable "workload_account_ids" {
  description = "ECRからimage pull可能なアカウントのID"
  type        = list(string)

  validation {
    condition     = alltrue([for id in var.workload_account_ids : can(regex("^[0-9]{12}$", id))])
    error_message = "アカウントIDは12桁の数字"
  }
}
