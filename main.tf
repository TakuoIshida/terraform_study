provider "aws" {
  region = "ap-northeast-1"
}
locals {
  default_ami  = "ami-0c3fd0f5d33134a76"
  project_name = "hoge"
}

variable "default_instance_type" {
  default = "t2.micro"
}

resource "aws_security_group" "test_scg" {
  name = local.project_name + "scg"

  ingress = [{
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }]
  egress = [{
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }]
}

resource "aws_instance" "ishida" {
  ami                    = local.default_ami
  instance_type          = var.default_instance_type
  vpc_security_group_ids = [aws_security_group.tenancy]
  tags = {
    "Name" = "value"
  }
}
output "instance_id" {
  value = aws_instance.ishida
}
