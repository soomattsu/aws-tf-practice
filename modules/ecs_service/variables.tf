variable "name_prefix" {
  description = "リソース名の接頭辞"
  type        = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ecs_cluster_id" {
  description = "ECS Serviceが配備されるClusterのID"
  type        = string
}

variable "service_name" {
  description = "ECS Service名"
  type        = string
}

variable "private_subnet_ids" {
  description = "ECS Serviceが配下のTaskを配置するサブネットのID"
  type        = list(string)
}

variable "alb_target_group_arn" {
  description = "ECS Serviceが配下のTaskをALBのTGへ登録するためのARN"
  type        = string
}

variable "alb_security_group_id" {
  description = "ECS TaskがALBからの転送ingressを受け取るためのSG参照用ID"
  type        = string
}
