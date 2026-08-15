variable "region" {
  type = string
}

variable "profile" {
  type        = string
  description = "Workloads/Prod OUのprofile"
}

variable "trusted_account_id" {
  type        = string
  description = "Terraformを実行するアカウント（Workloads/Prod OU上のTerraform用RoleをAssumeできるアカウント）のID"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.trusted_account_id))
    error_message = "アカウントIDは12桁の数字"
  }
}

variable "role_name" {
  type        = string
  description = "Workloads/Prod OU上のTerraform用Roleの名前"
  default     = "TerraformExecutionRole"
}
