# =====================================================
# PROVIDER CONFIGURATION
# =====================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


# =====================================================
# VPC
# =====================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cloud-design-vpc"
  }
}


# =====================================================
# INTERNET GATEWAY
# =====================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cloud-design-igw"
  }
}


# =====================================================
# PUBLIC SUBNETS
# =====================================================

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloud-design-public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "cloud-design-public-b"
  }
}


# =====================================================
# PRIVATE SUBNETS
# =====================================================

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "cloud-design-private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "cloud-design-private-b"
  }
}


# =====================================================
# PUBLIC ROUTE TABLE
# =====================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "cloud-design-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}


# =====================================================
# NAT GATEWAY
# =====================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "cloud-design-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [
    aws_internet_gateway.main
  ]

  tags = {
    Name = "cloud-design-nat"
  }
}


# =====================================================
# PRIVATE ROUTE TABLE
# =====================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "cloud-design-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}


# =====================================================
# ALB SECURITY GROUP
# =====================================================

resource "aws_security_group" "alb" {
  name        = "cloud-design-alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

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

  tags = {
    Name = "cloud-design-alb-sg"
  }
}


# =====================================================
# ECS SECURITY GROUP
# =====================================================

resource "aws_security_group" "ecs" {
  name        = "cloud-design-ecs-sg"
  description = "Allow traffic from ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-ecs-sg"
  }
}


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


# =====================================================
# ECS CLUSTER
# =====================================================

resource "aws_ecs_cluster" "main" {
  name = "cloud-design-cluster"

  tags = {
    Name = "cloud-design-cluster"
  }
}


# =====================================================
# IAM ROLE FOR EC2 INSTANCES
# =====================================================

resource "aws_iam_role" "ecs_instance" {
  name = "cloud-design-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "cloud-design-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}


# =====================================================
# LAUNCH TEMPLATE
# =====================================================

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "cloud-design-ecs-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    EOF
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ecs.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "cloud-design-ecs-instance"
    }
  }
}


# =====================================================
# AUTO SCALING GROUP
# =====================================================

resource "aws_autoscaling_group" "ecs" {
  name                = "cloud-design-ecs-asg"
  vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "cloud-design-ecs-instance"
    propagate_at_launch = true
  }
}


# =====================================================
# CAPACITY PROVIDER
# =====================================================

resource "aws_ecs_capacity_provider" "main" {
  name = "cloud-design-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
    base              = 1
  }
}


# =====================================================
# ECS TASK EXECUTION ROLE
# =====================================================

data "aws_iam_policy_document" "ecs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "cloud-design-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# =====================================================
# ECS TASK ROLE
# =====================================================

resource "aws_iam_role" "ecs_task" {
  name               = "cloud-design-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}


# =====================================================
# ECS TASK DEFINITION
# =====================================================

resource "aws_ecs_task_definition" "api" {
  family                   = "cloud-design-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "api"
      image = "docker.io/oriax11/api-gateway-app:latest"

      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])

  # =====================================================
  # HOW TO ADD MORE CONTAINERS:
  # =====================================================
  # Add another JSON object to the array above:
  #
  # {
  #   name  = "another-container"
  #   image = "docker.io/your-image:tag"
  #   essential = true
  #   portMappings = [
  #     {
  #       containerPort = 8080
  #       hostPort      = 8080
  #       protocol      = "tcp"
  #     }
  #   ]
  # }
  #
  # NOTE: Total cpu/memory of all containers must not exceed 256/512
}


# =====================================================
# ECS SERVICE
# =====================================================

resource "aws_ecs_service" "api" {
  name            = "cloud-design-api-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "api"
    container_port   = 3000
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
    base              = 1
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.main
  ]
}


# =====================================================
# OUTPUTS
# =====================================================

output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "app_url" {
  value = "http://${aws_lb.main.dns_name}"
}