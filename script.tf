#-------------------------------------------------------
# Setting Up The Provider
#-------------------------------------------------------

provider "aws" {

  region = "ap-south-1" # The region you want to Provission the Sevtver

  #access_key = ""
  #secret_key = ""

}

#-------------------------------------------------------
# Module for Fetching the AMI ID
#-------------------------------------------------------


module "ami" {
  source = "./module/"
}

#-------------------------------------------------------
# Variables
#-------------------------------------------------------


variable "name" {

  default = "My_website"
}


variable "domain_name" {
  # This Will Ask the Domain_name
  
}


variable "database_name" {

  default = "wordpress"

}

variable "database_user" {

  default = "wordpress"

}

variable "database_password" {
  default = "4wmFaq7bpJ8KgdHH"
}

#-------------------------------------------------------
# Securty Group Creation
#-------------------------------------------------------


resource "aws_security_group" "mysite" {

  name        = "${var.name}-${var.domain_name}"
  description = "Allow Port 443,80 and 22"
  ingress {
    description      = "HTTP Traffics"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    protocol         = "tcp"
  }

  ingress {

    description      = "HTTPS Traffics"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]

  }

  ingress {

    description      = "SSH Allow"
    from_port        = "22"
    to_port          = "22"
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {

    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    "Name" = var.name
  }
  lifecycle {
    create_before_destroy = true
  }
}

#-------------------------------------------------------
# Createing KeyPair
#-------------------------------------------------------



resource "aws_key_pair" "key" {

  public_key = file("./Webserver_key.pub")

  tags = {
    "Name" = "${var.name}-${var.domain_name}"
  }

  lifecycle {
    create_before_destroy = true
  }
}


#-------------------------------------------------------
# Instance Creation
#-------------------------------------------------------


resource "aws_instance" "webserver" {

  ami                    = module.ami.id
  vpc_security_group_ids = [aws_security_group.mysite.id]
  key_name               = aws_key_pair.key.key_name
  instance_type          = "t2.micro"
  user_data              = data.template_file.wordpress.rendered
  tags = {
    "Name" = "${var.name}-${var.domain_name}"
  }
  lifecycle {
    create_before_destroy = true
  }
}


#------------------------------------------------------------
# Templete
#------------------------------------------------------------


data "template_file" "wordpress" {

  template = file("wordpress.sh")
  vars = {
    DATABASE_NAME     = var.database_name
    DATABASE_USER     = var.database_user
    DATABASE_PASSWORD = var.database_password
    DOMAIN_NAME       = var.domain_name
  }
}




#-------------------------------------------------------
# Application Loadbalancer Creation
#-------------------------------------------------------



resource "aws_lb" "mysite" {
  name        = "MyWebSite-ALB"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.mysite.id]
  subnets            = ["subnet-0819d8bda3d7c814e", "subnet-01304e8670afbcba5"]

  tags = {
    name        = "${var.name}-${var.domain_name}"
  }

}


#-------------------------------------------------------
# Target Group Creation
#-------------------------------------------------------


resource "aws_lb_target_group" "tg" {

  name        = "MyWebSite-ALB-Group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "vpc-08cb78227b44142f4"
  tags = {
    name        = "${var.name}-${var.domain_name}"
  }
}


#-------------------------------------------------------
# Target Group Attachment
#-------------------------------------------------------


resource "aws_lb_target_group_attachment" "tg_attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.webserver.id
  port             = 80

}


#-------------------------------------------------------
# Listener for HTTP
#-------------------------------------------------------



resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.mysite.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


#-------------------------------------------------------
# Listener for HTTPS
#-------------------------------------------------------

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.mysite.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:acm:ap-south-1:294836498545:certificate/8017b46e-c4b2-4e62-918c-02a392d436ad"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }

}


#-------------------------------------------------------
# DNS Record Creation
#-------------------------------------------------------



data "aws_route53_zone" "domain" {
  name = var.domain_name # Replace The Domain Name 
}

# ^^ This will Fetch the Zone ID from Route 53

resource "aws_route53_record" "A_record" {
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = var.domain_name
  type    = "A"

  alias {

    name                   = aws_lb.mysite.dns_name
    zone_id                = aws_lb.mysite.zone_id
    evaluate_target_health = true
  }

}

