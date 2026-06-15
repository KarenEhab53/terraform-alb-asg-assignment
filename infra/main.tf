# -------------------------
# DEFAULT VPC
# -------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_subnet" "details" {
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

locals {
  az_map = {
    for s in data.aws_subnet.details :
    s.availability_zone => s.id
  }

  selected_subnets = slice(values(local.az_map), 0, 2)
}

# -------------------------
# AMI
# -------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*"]
  }
}

# -------------------------
# SECURITY GROUPS
# -------------------------
resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# ALB
# -------------------------
resource "aws_lb" "alb" {
  name               = "assignment-alb"
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb_sg.id]
  subnets         = local.selected_subnets
}

# -------------------------
# TARGET GROUP
# -------------------------
resource "aws_lb_target_group" "tg" {
  name     = "assignment-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path = "/"
  }
}

# -------------------------
# LISTENER
# -------------------------
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# -------------------------
# LAUNCH TEMPLATE
# -------------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "assignment-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode("#!/bin/bash\nyum install -y httpd\necho 'Hello' > /var/www/html/index.html\nsystemctl start httpd\n")
}

# -------------------------
# AUTO SCALING GROUP
# -------------------------
resource "aws_autoscaling_group" "asg" {
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4

  vpc_zone_identifier = local.selected_subnets

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  health_check_type = "ELB"
}