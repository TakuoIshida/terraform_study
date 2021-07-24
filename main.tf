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
resource "aws_s3_bucket" "logging_bucket" {
  bucket = "my-terraform-lesson-logging"
  # 中が空でなくても破棄できるようにする場合
  # force_destroy = true 
  lifecycle_rule {
    enabled = true
    expiration {
      days = 180
    }
  }

}

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

# 8章 ALBとDNS
module "net_work" {
  source = "./net_work/"
  name   = "module-sg"
}

resource "aws_lb" "example_alb" {
  name                       = local.project_name
  load_balancer_type         = "application"
  internal                   = false //internetに公開する場合
  idle_timeout               = 60    //default: 60s
  enable_deletion_protection = true  //削除保護（本番の時に有効化する）
  access_logs {
    bucket  = aws_s3_bucket.logging_bucket.id
    enabled = true
  }
  security_groups = [] //TODO: SGのmodule化
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example_alb.arn
  port              = 80
  protocol          = "http"

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
resource "aws_route53_zone" "example_zone" {
  name = "test.example.com"
}

resource "aws_route53_record" "example_record" {
  zone_id = aws_route53_zone.example_zone.id
  name    = aws_route53_zone.example_zone.name
  type    = "A"

  alias {
    name                   = aws_lb.example_alb.dns_name
    zone_id                = aws_lb.example_alb.zone_id
    evaluate_target_health = true
  }
}

# ACM
resource "aws_acm_certificate" "example_acm" {
  domain_name               = aws_route53_record.example_record.name
  subject_alternative_names = [] //domain名の追加 P69 example.com , test.example.com
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true //新しいSSL証明書を作成してから、古い証明書を差し替える。defaultはfalse。terraform独自仕様。
  }
}

# 検証用 DNSレコード
resource "aws_route53_record" "example_certificate" {
  name    = aws_acm_certificate.example_acm.domain_validation_options[0].resource_record_name
  type    = aws_acm_certificate.example_acm.domain_validation_options[0].resource_record_type
  records = [aws_acm_certificate.example_acm.domain_validation_options[0].resource_record_value]
  zone_id = aws_route53_zone.example_zone.id
  ttl     = 60 //Time To Live: 有効寿命
}

resource "aws_acm_certificate_validation" "example_validation" {
  certificate_arn         = aws_acm_certificate.example_acm.arn
  validation_record_fqdns = [aws_route53_record.example_certificate.fdqn]
}

# HTTPS用ロードバランサー
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "hello"
      status_code  = 200
    }
  }
}

# target group
resource "aws_lb_target_group" "example_target" {
  name        = join("-", [local.project_name, "target_group"])
  target_type = "ip"
  # vpc_id = vpc.id
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
  listener_arn = aws_lb_listener.https.arn
  priority     = 100 //小さいほど優先度高い

  # フォワード先のターゲットグループの設定
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example_target.arn
  }

  # パスベースのルール
  condition {
    field  = "path-pattern"
    values = ["/*"] //すべてのPathにマッチする
  }
}
