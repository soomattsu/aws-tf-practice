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
}

variable "role_name" {
  type        = string
  description = "Workloads/Prod OU上のTerraform用Roleの名前"
  default     = "TerraformExecutionRole"
}
