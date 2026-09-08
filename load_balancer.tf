# =====================================================
# APPLICATION LOAD BALANCER
# =====================================================

resource "aws_lb" "main" {
  name               = "cloud-design-alb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id
  ]

  tags = {
    Name = "cloud-design-alb"
  }
}


# =====================================================
# ALB TARGET GROUP
# =====================================================

resource "aws_lb_target_group" "app" {
  name        = "cloud-design-app"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    protocol = "HTTP"
    path     = "/"
    matcher  = "200"
  }

  tags = {
    Name = "cloud-design-app-tg"
  }
}


# =====================================================
# HTTP LISTENER (Only HTTP)
# =====================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
