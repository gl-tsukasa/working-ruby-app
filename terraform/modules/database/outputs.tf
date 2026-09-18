output "instance_id" { value = aws_db_instance.this.id }
output "instance_arn" { value = aws_db_instance.this.arn }
output "address" { value = aws_db_instance.this.address }
output "port" { value = local.port }
output "secret_arn" { value = aws_secretsmanager_secret.db.arn }
output "kms_key_arn" { value = aws_kms_key.rds.arn }
