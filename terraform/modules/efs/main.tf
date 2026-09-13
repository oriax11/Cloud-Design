# =====================================================
# EFS — one file system, one access point per database
# =====================================================

resource "aws_efs_file_system" "main" {
  encrypted = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = "cloud-design-efs"
  }
}

resource "aws_efs_mount_target" "a" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_a_id
  security_groups = [aws_security_group.inventory_db_efs.id]
}

resource "aws_efs_mount_target" "b" {
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_b_id
  security_groups = [aws_security_group.inventory_db_efs.id]
}

resource "aws_efs_access_point" "inventory_db" {
  file_system_id = aws_efs_file_system.main.id

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
    Name = "cloud-design-inventory-db-ap"
  }
}

resource "aws_efs_access_point" "billing_db" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    uid = 101
    gid = 103
  }

  root_directory {
    path = "/billing-data"

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
# SECURITY GROUP: NFS (2049) from both database tasks
# =====================================================

resource "aws_security_group" "inventory_db_efs" {
  name        = "cloud-design-inventory-db-efs"
  description = "Allow NFS from inventory-db ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    description     = "NFS from inventory-db tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.inventory_db_sg_id]
  }

  ingress {
    description     = "NFS from billing-db tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [var.billing_db_sg_id]
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

# ---------------------------------------------------------------------------
# State migrations (shared FS + renamed mount targets; no recreation)
# ---------------------------------------------------------------------------

moved {
  from = aws_efs_file_system.inventory_db
  to   = aws_efs_file_system.main
}

moved {
  from = aws_efs_mount_target.inventory_db_a
  to   = aws_efs_mount_target.a
}

moved {
  from = aws_efs_mount_target.inventory_db_b
  to   = aws_efs_mount_target.b
}
