variable "env" {
  default = "dev"
}

resource "aws_security_group" "http_scg" {
  name = "http_scg_name"

  ingress = [{
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "value"
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    security_groups  = []
    self             = false
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "value"
    from_port        = 0
    to_port          = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "-1"
    security_groups  = []
    self             = false
  }]
}


resource "aws_instance" "http_instance" {
  ami                    = "ami-0c3fd0f5d33134a76"
  vpc_security_group_ids = [aws_security_group.http_scg.id]
  instance_type          = var.env == "dev" ? "t2.micro" : "m5.large"
  # key_name               = "test-key"
  availability_zone      = "ap-northeast-1a"
  user_data              = file("./http_server/user_data.sh")
  monitoring= true
}
