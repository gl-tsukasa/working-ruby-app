output "app_url" {
  description = "アプリの URL"
  value       = "${local.app_scheme}://${local.app_host}"
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "ecr_repository_url" {
  description = "docker push 先"
  value       = module.ecr.repository_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "migrate_task_definition_arn" {
  description = "CI から aws ecs run-task で db:prepare を流すときに使う"
  value       = module.ecs.migrate_task_definition_arn
}

output "private_subnet_ids" {
  description = "run-task の network-configuration に渡す"
  value       = module.network.private_subnet_ids
}

output "app_security_group_id" {
  value = module.security.app_sg_id
}

output "database_endpoint" {
  value = module.database.address
}

output "database_secret_arn" {
  description = "DATABASE_URL を含む Secrets Manager シークレット"
  value       = module.database.secret_arn
}

output "rails_master_key_secret_arn" {
  description = "RAILS_MASTER_KEY を投入するシークレット"
  value       = aws_secretsmanager_secret.rails_master_key.arn
}

output "active_storage_bucket" {
  value = module.storage.bucket_name
}

output "nat_gateway_public_ips" {
  description = "外部サービスの IP 許可リストに登録する送信元 IP"
  value       = module.network.nat_gateway_public_ips
}

output "cloudwatch_dashboard" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}
