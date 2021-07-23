provider "aws" {
  region = "ap-northeast-1"
}

locals {
  default_ami  = "ami-0c3fd0f5d33134a76"
  project_name = "hoge"
}

module "web_server" {
  source = "./http_server/"
}

output "public_dns" {
  value = module.web_server
}
