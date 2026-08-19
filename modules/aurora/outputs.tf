output "security_group_id" {
  description = "AuroraにIngress許可を付与するために、呼び出し側リソースが参照するSG ID"
  value       = aws_security_group.main.id
}

output "cluster_endpoint" {
  description = "writer instanceにresolveされるエンドポイント"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_port" {
  value = aws_rds_cluster.main.port
}

output "database_name" {
  value = aws_rds_cluster.main.database_name
}

output "master_user_secret_arn" {
  description = "RDSが生成したシークレットのARN"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}
