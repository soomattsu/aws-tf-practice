data "aws_caller_identity" "current" {}

locals {
  vpc_cidr = "10.0.0.0/16"
  subnets = [
    { "name" : "pub_c", "az" : "ap-northeast-1c", "cidr" : "10.0.0.0/24", "type" : "public" },
    { "name" : "pub_d", "az" : "ap-northeast-1d", "cidr" : "10.0.1.0/24", "type" : "public" },
    { "name" : "priv_c", "az" : "ap-northeast-1c", "cidr" : "10.0.10.0/24", "type" : "private" },
    { "name" : "priv_d", "az" : "ap-northeast-1d", "cidr" : "10.0.11.0/24", "type" : "private" }
  ]
  # subnetに紐づくリソースをAZで対応付けて参照するため、整形しておく
  pub_subnets  = { for s in local.subnets : s.az => s if s.type == "public" }
  priv_subnets = { for s in local.subnets : s.az => s if s.type == "private" }
}

resource "aws_vpc" "main" {
  cidr_block           = local.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "tf-practice-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id

  for_each                = { for s in local.subnets : s.name => s }
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.type == "public"

  tags = {
    Name = "tf-practice-subnet-${each.key}"
  }
}

# public subnetのEgress設定（IGW, RT）
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "tf-practice-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "tf-practice-public-route-table"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = local.pub_subnets
  route_table_id = aws_route_table.public.id
  subnet_id      = aws_subnet.main[each.value.name].id
}

# private subnetのEgress設定（NAT GW, RT）
resource "aws_eip" "nat" {
  domain   = "vpc"
  for_each = local.pub_subnets
  tags = {
    Name = "tf-practice-nat-eip-${each.value.name}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  for_each      = local.pub_subnets
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.main[each.value.name].id
  tags = {
    Name = "tf-practice-natgw-${each.value.name}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  for_each = local.priv_subnets
  vpc_id   = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = {
    Name = "tf-practice-private-route-table-${each.value.name}"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = local.priv_subnets
  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = aws_subnet.main[each.value.name].id
}

# ALB用SG（Terraformから作成したSGには、デフォルトのegress全許可は含まれないので、明示的Egressが必要）
resource "aws_security_group" "alb" {
  name        = "tf-practice-alb"
  description = "ALB ingress from Internet"
  vpc_id      = aws_vpc.main.id
  tags = {
    Name = "tf-practice-alb-sg"
  }
}

# port:80への全TCP通信を許可
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# 全egressを許可
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
