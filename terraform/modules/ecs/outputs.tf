output "cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "task_role_name" {
  value = aws_iam_role.ecs_task.name
}
