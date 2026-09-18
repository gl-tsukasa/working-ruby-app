locals {
  major_version = split(".", var.engine_version)[0]
  port          = 5432
}

############################################
# 認証情報
############################################
resource "random_password" "master" {
  length           = 32
  special          = true
  override_special = "!#$%^&*()-_=+[]{}<>:?" # URL に入れても壊れない文字だけ
}

############################################
# KMS (ストレージ / Performance Insights 暗号化)
############################################
resource "aws_kms_key" "rds" {
  description             = "${var.name_prefix} RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

############################################
# Subnet / Parameter group
############################################
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db"
  subnet_ids = var.subnet_ids
  tags       = { Name = "${var.name_prefix}-db" }
}

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.name_prefix}-pg${local.major_version}-"
  family      = "postgres${local.major_version}"

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # 1 秒超のクエリをログ
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  parameter {
    name  = "rds.force_ssl"
    value = "1"
  }

  lifecycle {
    create_before_destroy = true
  }
}

############################################
# Enhanced Monitoring 用ロール
############################################
data "aws_iam_policy_document" "monitoring_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  name               = "${var.name_prefix}-rds-monitoring"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume.json
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  role       = aws_iam_role.monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

############################################
# インスタンス
############################################
resource "aws_db_instance" "this" {
  identifier = "${var.name_prefix}-postgres"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result
  port     = local.port

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = aws_kms_key.rds.arn

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  parameter_group_name   = aws_db_parameter_group.this.name
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period   = var.backup_retention_days
  backup_window             = "17:00-18:00" # JST 02:00-03:00
  maintenance_window        = "Sun:18:00-Sun:19:00"
  copy_tags_to_snapshot     = true
  delete_automated_backups  = !var.is_prod
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = !var.is_prod
  final_snapshot_identifier = var.is_prod ? "${var.name_prefix}-postgres-final" : null

  auto_minor_version_upgrade = true
  apply_immediately          = !var.is_prod

  performance_insights_enabled          = true
  performance_insights_kms_key_id       = aws_kms_key.rds.arn
  performance_insights_retention_period = 7
  monitoring_interval                   = 60
  monitoring_role_arn                   = aws_iam_role.monitoring.arn
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  tags = { Name = "${var.name_prefix}-postgres" }

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

############################################
# Secrets Manager: 接続情報 (DATABASE_URL 含む)
############################################
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}/database"
  description             = "RDS PostgreSQL credentials for ${var.name_prefix}"
  recovery_window_in_days = var.is_prod ? 30 : 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    engine   = "postgres"
    host     = aws_db_instance.this.address
    port     = local.port
    dbname   = var.db_name
    username = var.db_username
    password = random_password.master.result
    # Rails は DATABASE_URL があれば database.yml にマージする
    url = "postgres://${var.db_username}:${urlencode(random_password.master.result)}@${aws_db_instance.this.address}:${local.port}/${var.db_name}?sslmode=require&pool=${var.rails_max_threads}"
  })
}
