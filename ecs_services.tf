# =====================================================
# SERVICE DISCOVERY NAMESPACE
# (lets services find each other by name, e.g.
# "inventory-app.cloud-design" from inside the api container)
# =====================================================

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "cloud-design"
  vpc  = aws_vpc.main.id
}


# =====================================================
# TASK DEFINITION: API
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
          name          = "api"
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
    }
  ])
}


# =====================================================
# TASK DEFINITION: INVENTORY
# =====================================================

resource "aws_ecs_task_definition" "inventory" {
  family                   = "cloud-design-inventory"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "512"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "inventory-app"
      image     = "docker.io/oriax11/inventory-app:latest"
      essential = true

      portMappings = [
        {
          name          = "inventory-app"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
    }
  ])
}


# =====================================================
# SERVICE: API (behind the ALB)
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

  service_connect_configuration {
    enabled   = true
    namespace = "cloud-design"

    service {
      port_name      = "api"
      discovery_name = "api"

      client_alias {
        dns_name = "api"
        port     = 3000
      }
    }
  }

  depends_on = [
    aws_lb_listener.http,
    aws_ecs_cluster_capacity_providers.main
  ]
}


# =====================================================
# SERVICE: INVENTORY (internal only, not behind the ALB)
# =====================================================

resource "aws_ecs_service" "inventory-app" {
  name                  = "cloud-design-inventory-service"
  cluster               = aws_ecs_cluster.main.id
  task_definition       = aws_ecs_task_definition.inventory.arn
  desired_count         = 1
  force_new_deployment  = true

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  service_connect_configuration {
    enabled   = true
    namespace = "cloud-design"

    service {
      port_name      = "inventory-app"
      discovery_name = "inventory-app"

      client_alias {
        dns_name = "inventory-app"
        port     = 8080
      }
    }
  }

  depends_on = [
    aws_service_discovery_private_dns_namespace.main,
    aws_ecs_cluster_capacity_providers.main
  ]
}
