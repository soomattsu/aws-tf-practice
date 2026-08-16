output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for k, v in aws_subnet.main : v.id if v.map_public_ip_on_launch]
}

output "private_subnet_ids" {
  value = [for k, v in aws_subnet.main : v.id if !v.map_public_ip_on_launch]
}
