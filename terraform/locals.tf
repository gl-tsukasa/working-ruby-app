locals {
  name_prefix = "${var.project_name}-${var.environment}"
  is_prod     = var.environment == "prod"

  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "gl-demo-ultimate-tkomatsubara/dairybuild/2026/09/17/r"
    },
    var.extra_tags,
  )

  # HTTPS が有効なら https:// で Rails に伝える
  app_scheme = var.acm_certificate_arn != "" ? "https" : "http"
  app_host   = var.domain_name != "" ? var.domain_name : module.alb.dns_name
}
