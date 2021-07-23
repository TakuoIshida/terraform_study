provider "aws" {
  region = local.region
}

locals {
  default_ami  = "ami-0c3fd0f5d33134a76"
  project_name = "my-project"
  region       = "ap-northeast-1"
  az_a         = "ap-northeast-1a"
  az_c         = "ap-northeast-1c"
}

# module "web_server" {
#   source = "./http_server/"
# }

# output "public_dns" {
#   value = module.web_server
# }

#6章 ストレージ
# S3 のprivate bucket
# resource "aws_s3_bucket" "my_private_bucket" {
#   bucket = "my-terraform-lesson" //globalに一意な名前
#   acl    = "private"
#   # policy = file("./bucket_policy.json") //json形式でバケットのポリシーを記述し、file()でimportする
#   versioning {
#     enabled = true
#   }

#   server_side_encryption_configuration {
#     rule {
#       apply_server_side_encryption_by_default {
#         sse_algorithm = "AES256" //  sse_algorithm     = "aws:kms"
#       }
#     }
#   }
# }

# S3 のpublic bucket
# resource "aws_s3_bucket" "my_public_bucket" {
#   bucket = "my-terraform-lesson-pub"
#   acl    = "public-read"
#   cors_rule {
#     allowed_origins = ["https://localhost:3000"]
#     allowed_methods = ["GET"]
#     allowed_headers = ["*"]
#     max_age_seconds = 3000
#   }
#   logging {
#     target_bucket = aws_s3_bucket.log_bucket.id
#     target_prefix = "log/"
#   }
# }

# S3 の Log bucket
# resource "aws_s3_bucket" "logging_bucket" {
#   bucket = "my-terraform-lesson-logging"
#   # 中が空でなくても破棄できるようにする場合
#   # force_destroy = true 
#   lifecycle_rule {
#     enabled = true
#     expiration {
#       days = 180
#     }
#   }

# }

# resource "aws_s3_bucket_policy" "alb_log" {
#   bucket = aws_s3_bucket.logging_bucket.id
#   policy = data.aws_iam_policy_document.alb_logging_policy.json
# }

# data "aws_iam_policy_document" "alb_logging_policy" {
#   statement {
#     effect    = "Allow"
#     actions   = ["S3:PutObject"]
#     resources = ["arn:aws:s3:::${aws_s3_bucket.logging_bucket.id}/*"]
#     principals {
#       type        = "AWS"
#       identifiers = ["988850671127"]
#     }
#   }
# }

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


# セキュリティグループの作り方
resource "aws_security_group" "example_security_group" {
  name   = join("-", [local.project_name, "scg"])
  vpc_id = aws_vpc.example.id
}

# ingress: 80ポートでリクエストを全て許可する場合
resource "aws_security_group_rule" "ingress_http_rule" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example_security_group.id
}

# egress: 全ての通信を許可する場合
resource "aws_security_group_rule" "egress_rule" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.example_security_group.id
}

