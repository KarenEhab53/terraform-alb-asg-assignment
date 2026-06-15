# -------------------------
# GET AMI
# -------------------------
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -------------------------
# USE EXISTING ASSIGNMENT VPC
# -------------------------
data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = ["assignment-vpc"]
  }
}

# -------------------------
# GET ALL SUBNETS IN ASSIGNMENT VPC
# -------------------------
data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

locals {
  selected_subnets = tolist(data.aws_subnets.all.ids)
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
# APPLICATION LOAD BALANCER
# -------------------------
resource "aws_lb" "alb" {
  name               = "assignment-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.selected_subnets
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
  name_prefix   = "assignment-lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    html_content = file("${path.module}/index.html")
  }))
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