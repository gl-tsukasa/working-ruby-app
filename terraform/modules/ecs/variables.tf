variable "name_prefix" { type = string }
variable "aws_region" { type = string }
variable "account_id" { type = string }
variable "is_prod" { type = bool }

variable "private_subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "target_group_arn" { type = string }
variable "alb_arn_suffix" { type = string }
variable "target_group_arn_suffix" { type = string }

variable "image" {
  description = "ECR イメージ URI (タグ込み)"
  type        = string
}
variable "app_port" { type = number }
variable "task_cpu" { type = number }
variable "task_memory" { type = number }
variable "desired_count" { type = number }
variable "min_capacity" { type = number }
variable "max_capacity" { type = number }
variable "use_fargate_spot" { type = bool }
variable "log_retention_days" { type = number }

variable "environment_variables" {
  description = "コンテナに渡す平文の環境変数"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "コンテナに渡すシークレット。キー = 環境変数名、値 = Secrets Manager の ARN (json キー指定含む)"
  type        = map(string)
  default     = {}
}

variable "secret_arns" {
  description = "実行ロールに GetSecretValue を許可する Secret の ARN 一覧"
  type        = list(string)
}

variable "kms_key_arns" {
  description = "シークレット復号に必要な KMS キー ARN"
  type        = list(string)
  default     = []
}

variable "s3_bucket_arn" {
  description = "タスクロールに読み書きを許可する Active Storage バケット"
  type        = string
}
