# =====================================================
# IAM ROLE FOR EC2 INSTANCES (lets ECS agent on the
# instance register with the cluster)
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
# ECS TASK EXECUTION ROLE (lets ECS pull images / write
# logs on the task's behalf)
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
# ECS TASK ROLE (permissions your *application code*
# uses at runtime, e.g. to call S3/DynamoDB. Currently
# has no policies attached, so it does nothing yet.)
# =====================================================

resource "aws_iam_role" "ecs_task" {
  name               = "cloud-design-ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role.json
}
