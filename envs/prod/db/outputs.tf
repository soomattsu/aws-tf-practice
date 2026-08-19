output "security_group_id" {
  description = "AuroraにIngress許可を付与するために、呼び出し側リソースが参照するSG ID"
  value       = module.aurora.security_group_id
}

output "cluster_endpoint" {
  description = "writer instanceにresolveされるエンドポイント"
  value       = module.aurora.cluster_endpoint
}

output "cluster_port" {
  value = module.aurora.cluster_port
}

output "database_name" {
  value = module.aurora.database_name
}

output "master_user_secret_arn" {
  description = "RDSが生成したシークレットのARN"
  value       = module.aurora.master_user_secret_arn
}
