output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "cd_role_arn" {
  value = aws_iam_role.cd.arn
}
