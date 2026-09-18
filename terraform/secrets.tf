# RAILS_MASTER_KEY (config/credentials.yml.enc の復号鍵)
resource "aws_secretsmanager_secret" "rails_master_key" {
  name                    = "${local.name_prefix}/rails-master-key"
  description             = "RAILS_MASTER_KEY for ${local.name_prefix}"
  recovery_window_in_days = local.is_prod ? 30 : 0
}

# 変数で渡されたときだけ Terraform が値を書く。
# 渡さない場合は `aws secretsmanager put-secret-value` で手動投入する。
resource "aws_secretsmanager_secret_version" "rails_master_key" {
  count = var.rails_master_key != "" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.rails_master_key.id
  secret_string = var.rails_master_key
}
