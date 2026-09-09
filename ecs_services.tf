# =====================================================
# SERVICE DISCOVERY NAMESPACE
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
      name      = "api"
      image     = "docker.io/oriax11/api-gateway-app:latest"
      essential = true

      portMappings = [
        {
          name          = "api"
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "INVENTORY_APP_HOST"
          value = "inventory-app"
        },
        {
          name  = "INVENTORY_APP_PORT"
          value = "8080"
        },
        {
          name  = "RABBITMQ_HOST"
          value = "rabbit-queue"
        },
        {
          name  = "RABBITMQ_PORT"
          value = "5672"
        },
        {
          name  = "RABBITMQ_QUEUE"
          value = "billing_queue"
        },
        {
          name  = "APIGATEWAY_PORT"
          value = "3000"
        }
      ]

      secrets = [
        {
          name      = "RABBITMQ_USER"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_USER::"
        },
        {
          name      = "RABBITMQ_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_PASSWORD::"
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
  memory = "256"

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
      environment = [
        {
          name  = "INVENTORY_APP_PORT"
          value = "8080"
        }
      ]

      secrets = [
        {
          name      = "INVENTORY_DB_USER"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:INVENTORY_DB_USER::"
        },
        {
          name      = "INVENTORY_DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:INVENTORY_DB_PASSWORD::"
        },
        {
          name      = "INVENTORY_DB_NAME"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:INVENTORY_DB_NAME::"
        }
      ]
    }


  ])
}

# =====================================================
# TASK DEFINITION: BILLING
# =====================================================

resource "aws_ecs_task_definition" "billing" {
  family                   = "cloud-design-billing"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "256"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "billing-app"
      image     = "docker.io/oriax11/billing-app:latest"
      essential = true

      portMappings = [
        {
          name          = "billing-app"
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "RABBITMQ_HOST"
          value = "rabbit-queue"
        },
        {
          name  = "RABBITMQ_PORT"
          value = "5672"
        },
        {
          name  = "BILLING_APP_PORT"
          value = "8080"
        }
      ]

      secrets = [
        {
          name      = "BILLING_DB_USER"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:BILLING_DB_USER::"
        },
        {
          name      = "BILLING_DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:BILLING_DB_PASSWORD::"
        },
        {
          name      = "BILLING_DB_NAME"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:BILLING_DB_NAME::"
        },
        {
          name      = "RABBITMQ_USER"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_USER::"
        },
        {
          name      = "RABBITMQ_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_PASSWORD::"
        },
        {
          name      = "RABBITMQ_QUEUE"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_QUEUE::"
        }
      ]
    }
  ])
}

# =====================================================
# TASK DEFINITION: RABBITMQ
# =====================================================

resource "aws_ecs_task_definition" "rabbit_queue" {
  family                   = "cloud-design-rabbit-queue"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "256"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "rabbit-queue"
      image     = "docker.io/oriax11/rabbit-queue:latest"
      essential = true

      portMappings = [
        {
          name          = "rabbitmq"
          containerPort = 5672
          hostPort      = 5672
          protocol      = "tcp"
        },
        {
          name          = "rabbitmq-management"
          containerPort = 15672
          hostPort      = 15672
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "RABBITMQ_USER"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_USER::"
        },
        {
          name      = "RABBITMQ_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_PASSWORD::"
        },
        {
          name      = "RABBITMQ_QUEUE"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:RABBITMQ_QUEUE::"
        }
      ]
    }
  ])
}

# =====================================================
# TASK DEFINITION: INVENTORY DB
# =====================================================

resource "aws_ecs_task_definition" "inventory_db" {
  family                   = "cloud-design-inventory-db"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "256"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "inventory-db"
      image     = "docker.io/oriax11/inventory-db:latest"
      essential = true

      portMappings = [
        {
          name          = "postgres"
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:INVENTORY_DB_USER::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:INVENTORY_DB_PASSWORD::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:INVENTORY_DB_NAME::"
        }
      ]
    }
  ])
}

# =====================================================
# TASK DEFINITION: BILLING DB
# =====================================================

resource "aws_ecs_task_definition" "billing_db" {
  family                   = "cloud-design-billing-db"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]

  cpu    = "256"
  memory = "256"

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "billing-db"
      image     = "docker.io/oriax11/billing-db:latest"
      essential = true

      portMappings = [
        {
          name          = "postgres"
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]
      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:BILLING_DB_USER::"
        },
        {
          name      = "DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:BILLING_DB_PASSWORD::"
        },
        {
          name      = "DB_NAME"
          valueFrom = "${aws_secretsmanager_secret.app.arn}:BILLING_DB_NAME::"
        }
      ]
    }
  ])
}

# =====================================================
# SERVICE: API (behind the ALB)
# =====================================================

resource "aws_ecs_service" "api" {
  name                   = "cloud-design-api-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.api.arn
  desired_count          = 1
  enable_execute_command = true


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
# SERVICE: INVENTORY
# =====================================================

resource "aws_ecs_service" "inventory_app" {
  name                   = "cloud-design-inventory-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.inventory.arn
  desired_count          = 1
  force_new_deployment   = true
  enable_execute_command = true


  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
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

# =====================================================
# SERVICE: BILLING
# =====================================================

resource "aws_ecs_service" "billing_app" {
  name                   = "cloud-design-billing-service"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.billing.arn
  desired_count          = 1
  force_new_deployment   = true
  enable_execute_command = true


  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
  }

  service_connect_configuration {
    enabled   = true
    namespace = "cloud-design"

    service {
      port_name      = "billing-app"
      discovery_name = "billing-app"

      client_alias {
        dns_name = "billing-app"
        port     = 8080
      }
    }
  }

  depends_on = [
    aws_service_discovery_private_dns_namespace.main,
    aws_ecs_cluster_capacity_providers.main
  ]
}

# =====================================================
# SERVICE: RABBITMQ
# =====================================================

resource "aws_ecs_service" "rabbit_queue" {
  name                   = "cloud-design-rabbit-queue"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.rabbit_queue.arn
  desired_count          = 1
  force_new_deployment   = true
  enable_execute_command = true


  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
  }

  service_connect_configuration {
    enabled   = true
    namespace = "cloud-design"

    service {
      port_name      = "rabbitmq"
      discovery_name = "rabbit-queue"

      client_alias {
        dns_name = "rabbit-queue"
        port     = 5672
      }
    }
  }

  depends_on = [
    aws_service_discovery_private_dns_namespace.main,
    aws_ecs_cluster_capacity_providers.main
  ]
}

# =====================================================
# SERVICE: INVENTORY DB
# =====================================================

resource "aws_ecs_service" "inventory_db" {
  name                 = "cloud-design-inventory-db"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.inventory_db.arn
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
  }

  service_connect_configuration {
    enabled   = true
    namespace = "cloud-design"

    service {
      port_name      = "postgres"
      discovery_name = "inventory-db"

      client_alias {
        dns_name = "inventory-db"
        port     = 5432
      }
    }
  }

  depends_on = [
    aws_service_discovery_private_dns_namespace.main,
    aws_ecs_cluster_capacity_providers.main
  ]
}

# =====================================================
# SERVICE: BILLING DB
# =====================================================

resource "aws_ecs_service" "billing_db" {
  name                 = "cloud-design-billing-db"
  cluster              = aws_ecs_cluster.main.id
  task_definition      = aws_ecs_task_definition.billing_db.arn
  desired_count        = 1
  force_new_deployment = true

  network_configuration {
    subnets = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
  }

  service_connect_configuration {
    enabled   = true
    namespace = "cloud-design"

    service {
      port_name      = "postgres"
      discovery_name = "billing-db"

      client_alias {
        dns_name = "billing-db"
        port     = 5432
      }
    }
  }

  depends_on = [
    aws_service_discovery_private_dns_namespace.main,
    aws_ecs_cluster_capacity_providers.main
  ]
}
