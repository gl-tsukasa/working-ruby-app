############################################
# 全体
############################################
variable "project_name" {
  description = "リソース名のプレフィックス"
  type        = string
  default     = "rails-app"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.project_name))
    error_message = "project_name は小文字英数字とハイフン、2〜21 文字。"
  }
}

variable "environment" {
  description = "環境名 (dev / stg / prod)"
  type        = string

  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "environment は dev / stg / prod のいずれか。"
  }
}

variable "aws_region" {
  description = "デプロイ先リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "extra_tags" {
  description = "全リソースに追加するタグ"
  type        = map(string)
  default     = {}
}

############################################
# ネットワーク
############################################
variable "vpc_cidr" {
  description = "VPC の CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "使用する AZ 数 (2 or 3)"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count は 2 か 3。"
  }
}

variable "single_nat_gateway" {
  description = "true なら NAT Gateway を 1 台に集約 (コスト優先)。prod は false 推奨"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "ECR / CloudWatch Logs / Secrets Manager / SSM の Interface Endpoint を作る"
  type        = bool
  default     = true
}

############################################
# アプリ (ECS)
############################################
variable "image_tag" {
  description = "デプロイする ECR イメージのタグ (CI から -var で渡す)"
  type        = string
  default     = "latest"
}

variable "app_port" {
  description = "Puma が listen するポート"
  type        = number
  default     = 3000
}

variable "task_cpu" {
  description = "Fargate タスク CPU (256 / 512 / 1024 / 2048 / 4096)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate タスクメモリ (MiB)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "web サービスの初期タスク数"
  type        = number
  default     = 2
}

variable "autoscaling_min_capacity" {
  type    = number
  default = 2
}

variable "autoscaling_max_capacity" {
  type    = number
  default = 6
}

variable "use_fargate_spot" {
  description = "true なら一部タスクを FARGATE_SPOT に載せる (dev 向け)"
  type        = bool
  default     = false
}

variable "rails_max_threads" {
  description = "RAILS_MAX_THREADS (Puma スレッド数 = DB プールサイズ)"
  type        = number
  default     = 5
}

variable "rails_master_key" {
  description = "config/master.key の中身。空なら Secrets Manager 側で手動投入する"
  type        = string
  default     = ""
  sensitive   = true
}

variable "health_check_path" {
  description = "ALB ヘルスチェックパス"
  type        = string
  default     = "/"
}

############################################
# データベース (RDS PostgreSQL)
############################################
variable "db_engine_version" {
  type    = string
  default = "16.4"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_allocated_storage" {
  description = "初期ストレージ (GiB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "ストレージ自動拡張の上限 (GiB)"
  type        = number
  default     = 100
}

variable "db_multi_az" {
  type    = bool
  default = false
}

variable "db_backup_retention_days" {
  type    = number
  default = 7
}

variable "db_deletion_protection" {
  type    = bool
  default = false
}

variable "db_name" {
  type    = string
  default = "my_application_production"
}

variable "db_username" {
  type    = string
  default = "my_application"
}

############################################
# ALB / ドメイン
############################################
variable "acm_certificate_arn" {
  description = "HTTPS 用 ACM 証明書 ARN。空なら HTTP のみ"
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "A レコードを作る Hosted Zone ID。空なら作らない"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "アプリの FQDN (route53_zone_id と併用)"
  type        = string
  default     = ""
}

variable "alb_deletion_protection" {
  type    = bool
  default = false
}

############################################
# 監視
############################################
variable "alarm_email" {
  description = "アラーム通知先メール。空なら SNS サブスクリプションを作らない"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  type    = number
  default = 30
}
