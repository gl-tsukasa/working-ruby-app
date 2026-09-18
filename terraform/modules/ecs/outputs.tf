output "cluster_name" { value = aws_ecs_cluster.this.name }
output "cluster_arn" { value = aws_ecs_cluster.this.arn }
output "service_name" { value = aws_ecs_service.web.name }
output "web_task_definition_arn" { value = aws_ecs_task_definition.web.arn }
output "migrate_task_definition_arn" { value = aws_ecs_task_definition.migrate.arn }
output "task_role_arn" { value = aws_iam_role.task.arn }
output "execution_role_arn" { value = aws_iam_role.execution.arn }
output "log_group_name" { value = aws_cloudwatch_log_group.app.name }
