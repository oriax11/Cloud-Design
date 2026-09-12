# =====================================================
# ECS CLUSTER
# =====================================================

resource "aws_ecs_cluster" "main" {
  name = "cloud-design-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "cloud-design-cluster"
  }
}


# =====================================================
# LAUNCH TEMPLATE (EC2 instances that will host containers)
# =====================================================

# data "aws_ami" "amazon_linux_2" {
#   most_recent = true
#   owners      = ["amazon"]

#   filter {
#     name   = "name"
#     values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
#   }
# }

# resource "aws_instance" "ecs" {
#   ami           = data.aws_ami.amazon_linux_2.id
#   instance_type = "t3.small"

#   subnet_id = aws_subnet.private_a.id

#   vpc_security_group_ids = [
#     aws_security_group.ecs.id
#   ]

#   iam_instance_profile = aws_iam_instance_profile.ecs_instance.name

#   user_data = <<-EOF
#     #!/bin/bash
#     echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
#   EOF

#   tags = {
#     Name = "cloud-design-ecs-instance"
#   }
# }

# resource "aws_launch_template" "ecs" {
#   name_prefix   = "cloud-design-ecs-"
#   image_id      = data.aws_ami.amazon_linux_2.id
#   instance_type = "t3.small"

#   user_data = base64encode(<<-EOF
#     #!/bin/bash
#     echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
#     EOF
#   )

#   iam_instance_profile {
#     name = aws_iam_instance_profile.ecs_instance.name
#   }

#   network_interfaces {
#     associate_public_ip_address = false
#     security_groups             = [aws_security_group.ecs.id]
#   }

#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name = "cloud-design-ecs-instance"
#     }
#   }
# }


# =====================================================
# AUTO SCALING GROUP
# =====================================================

# resource "aws_autoscaling_group" "ecs" {
#   name                = "cloud-design-ecs-asg"
#   vpc_zone_identifier = [aws_subnet.private_a.id, aws_subnet.private_b.id]

#   min_size         = 1
#   max_size         = 2
#   desired_capacity = 1

#   launch_template {
#     id      = aws_launch_template.ecs.id
#     version = "$Latest"
#   }

#   tag {
#     key                 = "Name"
#     value               = "cloud-design-ecs-instance"
#     propagate_at_launch = true
#   }
# }


# =====================================================
# CAPACITY PROVIDER (links the ASG to the ECS cluster
# so the cluster can scale EC2 capacity for you)
# =====================================================

# resource "aws_ecs_capacity_provider" "main" {
#   name = "cloud-design-capacity-provider"

#   auto_scaling_group_provider {
#     auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
#   }
# }

# resource "aws_ecs_cluster_capacity_providers" "main" {
#   cluster_name       = aws_ecs_cluster.main.name
#   capacity_providers = [aws_ecs_capacity_provider.main.name]

#   default_capacity_provider_strategy {
#     capacity_provider = aws_ecs_capacity_provider.main.name
#     weight            = 100
#     base              = 1
#   }
# }
