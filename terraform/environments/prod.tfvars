environment = "prod"
aws_region  = "ap-northeast-1"

# ネットワーク: AZ ごとに NAT
vpc_cidr           = "10.20.0.0/16"
az_count           = 3
single_nat_gateway = false

# アプリ
task_cpu                 = 1024
task_memory              = 2048
desired_count            = 3
autoscaling_min_capacity = 3
autoscaling_max_capacity = 12
use_fargate_spot         = false
rails_max_threads        = 5

# DB
db_instance_class        = "db.r6g.large"
db_allocated_storage     = 100
db_max_allocated_storage = 500
db_multi_az              = true
db_backup_retention_days = 14
db_deletion_protection   = true

# ドメイン / TLS (作成後に埋める)
# acm_certificate_arn = "arn:aws:acm:ap-northeast-1:123456789012:certificate/..."
# route53_zone_id     = "Z0123456789ABCDEFGHIJ"
# domain_name         = "app.example.com"

alb_deletion_protection = true
log_retention_days      = 90
# alarm_email = "ops@example.com"
