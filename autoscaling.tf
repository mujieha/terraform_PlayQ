resource "aws_vpc" "playq-vpc" {
  cidr_block = "192.168.0.0/16"
  enable_dns_support = "true"
  enable_dns_hostnames = "true"
}

resource "aws_subnet" "playqpriva" {
  vpc_id            = aws_vpc.playq-vpc.id
  cidr_block        = "192.168.128.0/18"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "private-us-east-1a"
  }
}

resource "aws_subnet" "playqprivb" {
  vpc_id            = aws_vpc.playq-vpc.id
  cidr_block        = "192.168.192.0/18"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "private-us-east-1b"
  }
}

resource "aws_subnet" "playq-puba" {
  vpc_id                  = aws_vpc.playq-vpc.id
  cidr_block              = "192.168.0.0/18"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "public-us-east-1a"
  }
}

resource "aws_subnet" "playq-pubb" {
  vpc_id                  = aws_vpc.playq-vpc.id
  cidr_block              = "192.168.64.0/18"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    "Name" = "public-us-east-1b"
  }
}

resource "aws_security_group" "playqec" {
  name = "playqec"
  vpc_id = aws_vpc.playq-vpc.id
}

resource "aws_security_group_rule" "ingress_app" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = aws_security_group.playqec.id
  source_security_group_id = aws_security_group.playqalb.id
}

resource "aws_security_group_rule" "ingress_ssh" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  cidr_blocks              = ["95.67.126.107/32", "76.169.181.157/32"]
  security_group_id        = aws_security_group.playqec.id
}

resource "aws_security_group_rule" "ingress_hc" {
  type                     = "ingress"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.playqec.id
  source_security_group_id = aws_security_group.playqalb.id
}

resource "aws_security_group_rule" "egress_ec2" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.playqec.id
}

resource "aws_internet_gateway" "playq-igw" {
  vpc_id = aws_vpc.playq-vpc.id

  tags = {
    Name = "playq-igw"
  }
}

resource "aws_eip" "nat" {
  vpc = true

  tags = {
    Name = "nat"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.playq-puba.id

  tags = {
    Name = "nat"
  }

  depends_on = [aws_internet_gateway.playq-igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.playq-vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.playq-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.playq-igw.id
  }

  tags = {
    Name = "public"
  }
}

resource "aws_route_table_association" "priva" {
  subnet_id      = aws_subnet.playqpriva.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "privb" {
  subnet_id      = aws_subnet.playqprivb.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "puba" {
  subnet_id      = aws_subnet.playq-puba.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "pubb" {
  subnet_id      = aws_subnet.playq-pubb.id
  route_table_id = aws_route_table.public.id
}

data "aws_key_pair" "webservers" {
  key_name = "webservers"
}

resource "aws_launch_template" "playq-lt" {
  name_prefix = "playq-lt"
  image_id      = "ami-0aa7d40eeae50c9a9"
  instance_type = "t2.micro"
  key_name      = "webservers"
  user_data     = filebase64("userdata.sh")
  depends_on = [aws_internet_gateway.playq-igw]
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "PlayQ-2019"
      Type = "webserver"
    }
  }
  vpc_security_group_ids = [aws_security_group.playqec.id]
}

resource "aws_autoscaling_group" "playq-asg" {
  name     = "playq-asg"
  max_size             = 3
  min_size             = 1
  desired_capacity     = 2
  depends_on = [aws_internet_gateway.playq-igw]
  health_check_type = "ELB"
  vpc_zone_identifier = [
    aws_subnet.playq-puba.id,
    aws_subnet.playq-pubb.id
  ]
  target_group_arns = [aws_alb_target_group.playq-tg.arn]
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.playq-lt.id
        version            = "$Latest"
      }
    }
  }
  tag {
    key                 = "Name"
    value               = "PlayQ-2019"
    propagate_at_launch = true
  }
  tag {
    key                 = "Type"
    value               = "webserver"
    propagate_at_launch = true
  }
}

resource "aws_alb_target_group" "playq-tg" {
  name     = "playq-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.playq-vpc.id
  health_check {
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_autoscaling_policy" "playq-scalepol" {
  name                   = "playq-scalepol"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.playq-asg.name

  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 50.0
  }
}