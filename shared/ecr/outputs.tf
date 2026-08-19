output "repository_urls" {
  description = "サービス名 => ECR repository URL"
  value       = { for k, v in aws_ecr_repository.main : k => v.repository_url }
}
