variable "name_prefix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "DBサブネットグループとなるプライベートサブネット（複数AZ）"
  type        = list(string)
}

variable "database_name" {
  description = "クラスタ作成時のDB名"
  type        = string
}

variable "port" {
  type    = number
  default = 3306
}

variable "instance_class" {
  description = "DBインスタンスのクラス"
  type        = string
}
