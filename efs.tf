# =====================================================
# EFS: INVENTORY DB
# =====================================================

resource "aws_efs_file_system" "inventory_db" {
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "cloud-design-inventory-db"
  }
}

resource "aws_efs_mount_target" "inventory_db_a" {
  file_system_id  = aws_efs_file_system.inventory_db.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.inventory_db_efs.id]
}

resource "aws_efs_mount_target" "inventory_db_b" {
  file_system_id  = aws_efs_file_system.inventory_db.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.inventory_db_efs.id]
}

resource "aws_efs_access_point" "inventory_db" {
  file_system_id = aws_efs_file_system.inventory_db.id

  posix_user {
    uid = 101 # postgres user in most official postgres images
    gid = 103
  }

  root_directory {
    path = "/postgres-data"

    creation_info {
      owner_uid   = 101
      owner_gid   = 103
      permissions = "0700"
    }
  }

  tags = {
    Name = "cloud-design-inventory-db-ap"
  }
}


# =====================================================
# EFS: BILLING DB
# =====================================================

resource "aws_efs_file_system" "billing_db" {
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "cloud-design-billing-db"
  }
}

resource "aws_efs_mount_target" "billing_db_a" {
  file_system_id  = aws_efs_file_system.billing_db.id
  subnet_id       = aws_subnet.private_a.id
  security_groups = [aws_security_group.billing_db_efs.id]
}

resource "aws_efs_mount_target" "billing_db_b" {
  file_system_id  = aws_efs_file_system.billing_db.id
  subnet_id       = aws_subnet.private_b.id
  security_groups = [aws_security_group.billing_db_efs.id]
}

resource "aws_efs_access_point" "billing_db" {
  file_system_id = aws_efs_file_system.billing_db.id

  posix_user {
    uid = 101
    gid = 103
  }

  root_directory {
    path = "/postgres-data"

    creation_info {
      owner_uid   = 101
      owner_gid   = 103
      permissions = "0700"
    }
  }

  tags = {
    Name = "cloud-design-billing-db-ap"
  }
}


# =====================================================
# SECURITY GROUPS: EFS MOUNT TARGETS
# NFS (port 2049) inbound only from the matching DB task's SG
# =====================================================

resource "aws_security_group" "inventory_db_efs" {
  name        = "cloud-design-inventory-db-efs"
  description = "Allow NFS from inventory-db ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from inventory-db tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.inventory_db.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-inventory-db-efs"
  }
}

resource "aws_security_group" "billing_db_efs" {
  name        = "cloud-design-billing-db-efs"
  description = "Allow NFS from billing-db ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "NFS from billing-db tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.billing_db.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cloud-design-billing-db-efs"
  }
}


# =====================================================
# IAM: allow the ECS task role to mount/read/write EFS
# Attach this policy to aws_iam_role.ecs_task
# =====================================================

resource "aws_iam_policy" "efs_access" {
  name        = "cloud-design-efs-access"
  description = "Allow ECS tasks to mount and access EFS access points for the DB volumes"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEFSClientMountWrite"
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = [
          aws_efs_file_system.inventory_db.arn,
          aws_efs_file_system.billing_db.arn
        ]
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = [
              aws_efs_access_point.inventory_db.arn,
              aws_efs_access_point.billing_db.arn
            ]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_efs_access" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.efs_access.arn
}
