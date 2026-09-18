environment = "dev"
aws_region  = "ap-northeast-1"

# ネットワーク: コスト優先
vpc_cidr           = "10.10.0.0/16"
az_count           = 2
single_nat_gateway = true

# アプリ
task_cpu                 = 512
task_memory              = 1024
desired_count            = 1
autoscaling_min_capacity = 1
autoscaling_max_capacity = 3
use_fargate_spot         = true

# DB
db_instance_class        = "db.t4g.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 50
db_multi_az              = false
db_backup_retention_days = 1
db_deletion_protection   = false

alb_deletion_protection = false
log_retention_days      = 14
