locals {
  # subnetに紐づくリソースをAZで対応付けて参照するため、整形しておく
  pub_subnets  = { for s in var.subnets : s.az => s if s.type == "public" }
  priv_subnets = { for s in var.subnets : s.az => s if s.type == "private" }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id

  for_each                = { for s in var.subnets : s.name => s }
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.type == "public"

  tags = {
    Name = "${var.name_prefix}-subnet-${each.key}"
  }
}

# public subnetのEgress設定（IGW, RT）
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-public-route-table"
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
    Name = "${var.name_prefix}-nat-eip-${each.value.name}"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  for_each      = local.pub_subnets
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.main[each.value.name].id
  tags = {
    Name = "${var.name_prefix}-natgw-${each.value.name}"
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
    Name = "${var.name_prefix}-private-route-table-${each.value.name}"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = local.priv_subnets
  route_table_id = aws_route_table.private[each.key].id
  subnet_id      = aws_subnet.main[each.value.name].id
}
