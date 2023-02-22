resource "aws_security_group" "playqalb" {
  name   = "playqalb"
  vpc_id = aws_vpc.playq-vpc.id
}

resource "aws_security_group_rule" "ingress_http" {
  type              = "ingress"
  from_port         = 8082
  to_port           = 8082
  protocol          = "tcp"
  security_group_id = aws_security_group.playqalb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "ingress_ht" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.playqalb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "egress_ht" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.playqalb.id
  source_security_group_id = aws_security_group.playqec.id
}

resource "aws_security_group_rule" "egress_alb" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.playqalb.id

}
resource "aws_security_group_rule" "egress_http" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.playqalb.id
  source_security_group_id = aws_security_group.playqec.id
}

resource "aws_security_group_rule" "egress_hc" {
  type                     = "egress"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.playqalb.id
  source_security_group_id = aws_security_group.playqec.id
}


resource "aws_alb" "playq-alb" {
  name               = "playq-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.playqalb.id]
  subnets = [
    aws_subnet.playq-puba.id,
    aws_subnet.playq-pubb.id
  ]
  preserve_host_header = true
}

resource "aws_alb_listener" "playq-hw" {
  load_balancer_arn = aws_alb.playq-alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.playq-tg.arn
  }
}

resource "aws_alb_listener_rule" "hh-rule" {
  listener_arn = aws_alb_listener.playq-hw.arn
  action {
    type = "forward"
    target_group_arn = aws_alb_target_group.playq-tg.arn
  }
  condition {
    host_header {
      values = [aws_alb.playq-alb.dns_name]
    }
  }
}

resource "aws_alb_listener" "playq-response-500" {
  load_balancer_arn = aws_alb.playq-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Oops! Let's try again"
      status_code  = "500"
    }
  }
}