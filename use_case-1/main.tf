resource "aws_instance" "openproject_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.openproject_sg.id]
  user_data              = <<-EOF
    #!/bin/bash
    sudo apt update -y
    curl -fsSL https://get.docker.com -o install-docker.sh
    sudo sh install-docker.sh
    sudo usermod -aG docker ubuntu
    docker run -d -p 80:80 \
     -e OPENPROJECT_SECRET_KEY_BASE=secret \
     -e OPENPROJECT_HTTPS=false \
     openproject/openproject:15.4.1

    EOF
  tags = {
    Name = "openproject"
  }
}

resource "aws_security_group" "openproject_sg" {
  name        = "openproject_sg"
  description = "Allow alb and ssh access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

resource "aws_alb" "alb" {
  name               = "openproject-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.openproject_sg.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "openproject_tg" {
  name        = "openproject-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/login"
    port                = "80"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
 
  tags = {
    Name = "openproject-tg"
  }
}

resource "aws_lb_target_group_attachment" "tg_attachment" {
  target_group_arn = aws_lb_target_group.openproject_tg.arn
  target_id        = aws_instance.openproject_instance.id
  port             = 80
}

resource "aws_lb_listener" "openproject_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.openproject_tg.arn
  }
}

