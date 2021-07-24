#7 章 ネットワーク
resource "aws_vpc" "example" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "hogehoge_tag" //nameはリソース名にも表示されるのであると見やすい
  }
}

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "192.168.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = local.az_a
  tags = {
    "Name" = join("-", [local.az_a, "public_1a"])
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "192.168.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = local.az_c
  tags = {
    "Name" = join("-", [local.az_c, "public_1c"])
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public_rt.id
  gateway_id             = aws_internet_gateway.igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.example.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_subnet" "private_1a" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "192.168.3.0/24"
  availability_zone       = local.az_a
  map_public_ip_on_launch = false
  tags = {
    "Name" = join("-", [local.az_a, "private_1a"])
  }
}

resource "aws_eip" "for_natgateway" {
  vpc = true
  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_nat_gateway" "exmple_gateway" {
  allocation_id = aws_eip.for_natgateway.id
  subnet_id     = aws_subnet.public_1a.id
  # internet gatewayが作成されてからNATGatewayの作成を実行する。依存関係の定義。
  depends_on = [
    aws_internet_gateway.igw
  ]
}

resource "aws_route" "nat_gateway_route" {
  route_table_id         = aws_route_table.private.id
  nat_gateway_id         = aws_nat_gateway.exmple_gateway.id
  destination_cidr_block = "0.0.0.0/0"
}
