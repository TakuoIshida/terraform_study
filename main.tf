provider "aws" {
  region = local.region
}

locals {
  default_ami  = "ami-0c3fd0f5d33134a76"
  project_name = "my-project"
  region       = "ap-northeast-1"
  az_a         = "ap-northeast-1a"
  az_c         = "ap-northeast-1c"
  env          = "dev"
}

#7 章 ネットワーク
resource "aws_vpc" "example" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    "Name" = "vpc_name" //nameはリソース名にも表示されるのであると見やすい
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

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
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

resource "aws_subnet" "private_1c" {
  vpc_id                  = aws_vpc.example.id
  cidr_block              = "192.168.4.0/24"
  availability_zone       = local.az_c
  map_public_ip_on_launch = false
  tags = {
    "Name" = join("-", [local.az_c, "private_1c"])
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
resource "aws_s3_bucket" "logging_bucket" {
  bucket = "my-terraform-lesson-logging"
  # 中が空でなくても破棄できるようにする場合
  # force_destroy = true 
  acl = "private"
  lifecycle_rule {
    enabled = true
    expiration {
      days = 180
    }
  }

}

resource "aws_s3_bucket_policy" "alb_log" {
  bucket = aws_s3_bucket.logging_bucket.id
  policy = data.aws_iam_policy_document.alb_logging_policy.json
}

data "aws_iam_policy_document" "alb_logging_policy" {
  statement {
    effect    = "Allow"
    actions   = ["S3:PutObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.logging_bucket.id}/*"]
    principals {
      type        = "AWS"
      identifiers = ["988850671127"]
    }
  }
}

# 8章 ALBとDNS
module "net_work" {
  source      = "./net_work/"
  name        = "module-sg"
  port        = 80
  environment = local.env
  vpc_id      = aws_vpc.example.id
  cidr_blocks = ["0.0.0.0/0"]
}

module "http_sg" {
  source      = "./net_work/"
  name        = "http-sg"
  port        = 80
  environment = local.env
  vpc_id      = aws_vpc.example.id
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_sg" {
  source      = "./net_work/"
  name        = "https-sg"
  port        = 443
  environment = local.env
  vpc_id      = aws_vpc.example.id
  cidr_blocks = ["0.0.0.0/0"]
}

module "https_redirect_sg" {
  source      = "./net_work/"
  name        = "http-redirect-sg"
  port        = 8080
  environment = local.env
  vpc_id      = aws_vpc.example.id
  cidr_blocks = ["0.0.0.0/0"]
}

module "nginx_sg" {
  source      = "./net_work/"
  name        = "nginx-sg"
  port        = 80
  environment = local.env
  vpc_id      = aws_vpc.example.id
  cidr_blocks = [aws_vpc.example.cidr_block]
}

resource "aws_lb" "example_alb" {
  name                       = local.project_name
  load_balancer_type         = "application"
  internal                   = false //internetに公開する場合
  idle_timeout               = 60    //default: 60s
  enable_deletion_protection = true  //削除保護（本番の時に有効化する）
  subnets                    = [aws_subnet.public_1a.id, aws_subnet.public_1c.id]

  # TODO: InvalidConfigurationRequest Access Denied for bucket
  # access_logs {
  #   bucket  = aws_s3_bucket.logging_bucket.id
  #   enabled = true
  # }
  security_groups = [
    module.http_sg.security_group_id,
    module.https_sg.security_group_id,
    module.https_redirect_sg.security_group_id,
  ]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "This is HTTP"
      status_code  = 200
    }
  }
}

output "alb_dns_name" {
  value = aws_lb.example_alb.dns_name
}

# DNS レコード
# resource "aws_route53_zone" "example_zone" {
#   name = "test.example.info"
# }

# resource "aws_route53_record" "example_record" {
#   zone_id = aws_route53_zone.example_zone.id
#   name    = aws_route53_zone.example_zone.name
#   type    = "A"

#   alias {
#     name                   = aws_lb.example_alb.dns_name
#     zone_id                = aws_lb.example_alb.zone_id
#     evaluate_target_health = true
#   }
# }

# ACM
# resource "aws_acm_certificate" "example_acm" {
#   domain_name               = aws_route53_record.example_record.name
#   subject_alternative_names = [] //domain名の追加 P69 example.com , test.example.com
#   validation_method         = "DNS"
#   lifecycle {
#     create_before_destroy = true //新しいSSL証明書を作成してから、古い証明書を差し替える。defaultはfalse。terraform独自仕様。
#   }
# }

# 検証用 DNSレコード
# resource "aws_route53_record" "example_certificate" {
#   name    = aws_acm_certificate.example_acm.domain_validation_options[0].resource_record_name
#   type    = aws_acm_certificate.example_acm.domain_validation_options[0].resource_record_type
#   records = [aws_acm_certificate.example_acm.domain_validation_options[0].resource_record_value]
#   zone_id = aws_route53_zone.example_zone.id
#   ttl     = 60 //Time To Live: 有効寿命
# }

# resource "aws_acm_certificate_validation" "example_validation" {
#   certificate_arn         = aws_acm_certificate.example_acm.arn
#   validation_record_fqdns = [aws_route53_record.example_certificate.fdqn]
# }

# # HTTPS用ロードバランサー
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.example_alb.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-2016-08"
#   default_action {
#     type = "fixed-response"
#     fixed_response {
#       content_type = "text/plain"
#       message_body = "hello"
#       status_code  = 200
#     }
#   }
# }

# target group
resource "aws_lb_target_group" "example_target" {
  name                 = "exampletarget"
  target_type          = "ip"
  vpc_id               = aws_vpc.example.id
  port                 = 80
  protocol             = "HTTP"
  deregistration_delay = 300 //ターゲットの登録を解除する前に、ALBが待機する時間。デフォルト：300s
  health_check {
    path                = "/"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = 200            //正常判定に使用するためのステータスコード
    port                = "traffic-port" //ヘルスチェックで使用するPORT
    protocol            = "HTTP"
  }
  # albが作成されてから、ターゲットグループを定義する（依存関係）
  depends_on = [
    aws_lb.example_alb
  ]
}

# リスナールール
resource "aws_lb_listener_rule" "example_listner_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100 //小さいほど優先度高い

  # フォワード先のターゲットグループの設定
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example_target.arn
  }

  # パスベースのルール
  condition {
    path_pattern {
      values = ["/*"] //すべてのPathにマッチする
    }
  }
}

# 9章 コンテナオーケストレーション
# ECS クラスタ
resource "aws_ecs_cluster" "example_cluster" {
  name = "ecs_cluster"
}

# task 定義
resource "aws_ecs_task_definition" "example_task" {
  family                   = "example" // タスク定義名：taskのFamilyにリビジョン番号を付与したもの。example:1
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  container_definitions    = file("./container_definitions.json")
  network_mode             = "awsvpc"
  # essential: タスク実行に必須かどうか？
  # image: 使用するコンテナImage
  # portMappings: マッピングするコンテナーのポート番号
}

# ECSサービス
resource "aws_ecs_service" "example_service" {
  name                              = "example"
  cluster                           = aws_ecs_cluster.example_cluster.arn
  task_definition                   = aws_ecs_task_definition.example_task.arn
  desired_count                     = 2
  launch_type                       = "FARGATE"
  platform_version                  = "1.3.0"
  health_check_grace_period_seconds = 60 //task起動までに時間がかかる場合に0秒の場合、起動と終了が延々と続いてしまう。default: 0s

  network_configuration {
    assign_public_ip = false
    security_groups  = [module.nginx_sg.security_group_id]
    subnets = [
      aws_subnet.private_1a.id,
      aws_subnet.private_1c.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example_target.arn
    container_name   = "example"
    container_port   = 80
  }

  lifecycle {
    # taskは初回以降起動終了を繰り返すので、plan時に差分がでる。タスク定義の変更は無視すべき。
    ignore_changes = [
      task_definition
    ]
  }
}

