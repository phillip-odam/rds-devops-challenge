terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "rds"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16" 
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_eip" "ngw" {
  domain = "vpc"
}

resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.ngw.id
  subnet_id = aws_subnet.public_0.id
}

resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.ngw.id
  }
}

resource "aws_main_route_table_association" "rta" {
  vpc_id = aws_vpc.vpc.id
  route_table_id = aws_route_table.rt_public.id
}

resource "aws_route_table_association" "rta_private_0" {
  subnet_id = aws_subnet.private_0.id
  route_table_id = aws_route_table.rt_private.id
}

resource "aws_route_table_association" "rta_private_1" {
  subnet_id = aws_subnet.private_1.id
  route_table_id = aws_route_table.rt_private.id
}

resource "aws_subnet" "public_0" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1c"
}

resource "aws_subnet" "private_0" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.128.0/22"
  availability_zone = "us-east-1c"
}

resource "aws_subnet" "public_1" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1d"
}

resource "aws_subnet" "private_1" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = "10.0.132.0/22"
  availability_zone = "us-east-1d"
}

resource "aws_security_group" "allow_web" {
  name = "allow_web"
  description = "Allow HTTP and HTTPS inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 80
  ip_protocol = "tcp"
  to_port = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_https_ipv4" {
  security_group_id = aws_security_group.allow_web.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port = 443
  ip_protocol = "tcp"
  to_port = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_web_egress" {
  security_group_id = aws_security_group.allow_web.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_security_group" "allow_backend" {
  name = "allow_backend"
  description = "Allow ALB and SSH inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "allow_alb" {
  security_group_id = aws_security_group.allow_backend.id
  referenced_security_group_id = aws_security_group.allow_web.id
  from_port = 80
  ip_protocol = "tcp"
  to_port = 80
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.allow_backend.id
  cidr_ipv4 = aws_vpc.vpc.cidr_block
  from_port = 22
  ip_protocol = "tcp"
  to_port = 22
}

resource "aws_vpc_security_group_egress_rule" "allow_backend_egress" {
  security_group_id = aws_security_group.allow_backend.id
  ip_protocol = "-1"
  cidr_ipv4 = "0.0.0.0/0"
}

resource "aws_alb" "web" {
  name = "web-load-balancer"
  internal = false
  load_balancer_type = "application"
  security_groups = [ aws_security_group.allow_web.id ]
  subnets = [ aws_subnet.public_0.id, aws_subnet.public_1.id ]
}

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_alb.web.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.web_tg.arn
  }
}

resource "tls_private_key" "web_tls" {
  algorithm = "RSA"
}

resource "tls_self_signed_cert" "web_tls" {
  private_key_pem = tls_private_key.web_tls.private_key_pem

  subject {
    common_name = "example-domain.com"
    organization = "Example Organization"
  }

  validity_period_hours = 1

  allowed_uses = [
    "server_auth"
  ]
}

resource "aws_acm_certificate" "web_tls" {
  private_key = tls_private_key.web_tls.private_key_pem
  certificate_body = tls_self_signed_cert.web_tls.cert_pem
}

resource "aws_lb_listener" "web_tls" {
  load_balancer_arn = aws_alb.web.arn
  port = "443"
  protocol = "HTTPS"
  ssl_policy = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate.web_tls.arn

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.web_tg.arn
  }
}

resource "aws_alb_target_group" "web_tg" {
  vpc_id = aws_vpc.vpc.id
  target_type = "instance"
  port = 80
  protocol = "HTTP"
}

resource "aws_alb_target_group_attachment" "web" {
  target_group_arn = aws_alb_target_group.web_tg.arn
  target_id = aws_instance.web_server.id
  port = 80
}

resource "aws_instance" "web_server" {
  ami = "ami-0a5b3d67a84b13bf9"
  instance_type = "t4g.nano"
  subnet_id = aws_subnet.private_0.id

  vpc_security_group_ids = [
    aws_security_group.allow_backend.id
  ]

  user_data = file("userdata.sh")

  depends_on = [ aws_route_table_association.rta_private_0 ]
}

output "message" {
  value = "ALB DNS name ${aws_alb.web.dns_name}, private IP of EC2 instance ${aws_instance.web_server.private_ip}"
}
