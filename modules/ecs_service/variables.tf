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

variable "containers" {
  description = "Taskを構成するコンテナ群の定義（コンテナ名 => コンテナ定義）"
  type = map(object({
    image     = string
    essential = optional(bool, true)
    port      = optional(number) # Task外にexposeするport
    # dockerLabel(コンテナ単位のメタデータ)として、dd-agentがECS task metadata endpoint経由で読むタグを付与する
    docker_labels = optional(map(string), {})
    environment   = optional(map(string), {})
    secrets = optional(map(object({
      arn      = string           # Secrets Manager上のシークレットのARN
      json_key = optional(string) # シークレットJSON内の特定キーのみ参照する場合に指定する
    })), {})
    # 未指定時は、モジュールが管理するCloudWatchのロググループへawslogsで転送
    log_configuration = optional(object({
      driver         = string
      options        = optional(map(string), {})
      secret_options = optional(map(string), {})
    }))
    # logDriver=awsfirelens の際に、log-routerとして動作するsidecarに指定する
    firelens_configuration = optional(object({
      type    = string
      options = optional(map(string), {})
    }))
  }))
}

variable "alb_integration" {
  description = "TaskをALBのターゲットとして登録するための設定"
  type = object({
    target_group_arn      = string # Taskが登録されるTGのARN
    security_group_id     = string # Taskのingress元として許可するALB SGのID
    target_container_name = string # Taskの内、実際にトラフィックが転送されるコンテナの名前
  })
}
