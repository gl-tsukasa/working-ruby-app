module "network" {
  source = "./modules/network"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  azs                  = local.azs
  single_nat_gateway   = var.single_nat_gateway
  enable_vpc_endpoints = var.enable_vpc_endpoints
  log_retention_days   = var.log_retention_days
}

module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  vpc_id      = module.network.vpc_id
  app_port    = var.app_port
}

module "ecr" {
  source = "./modules/ecr"

  name    = local.name_prefix
  is_prod = local.is_prod
}

module "storage" {
  source = "./modules/storage"

  name_prefix     = local.name_prefix
  account_id      = data.aws_caller_identity.current.account_id
  is_prod         = local.is_prod
  allowed_origins = var.domain_name != "" ? ["${local.app_scheme}://${var.domain_name}"] : []
}

module "database" {
  source = "./modules/database"

  name_prefix           = local.name_prefix
  subnet_ids            = module.network.database_subnet_ids
  security_group_ids    = [module.security.db_sg_id]
  engine_version        = var.db_engine_version
  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
  deletion_protection   = var.db_deletion_protection
  db_name               = var.db_name
  db_username           = var.db_username
  rails_max_threads     = var.rails_max_threads
  is_prod               = local.is_prod
}

module "alb" {
  source = "./modules/alb"

  name_prefix         = local.name_prefix
  vpc_id              = module.network.vpc_id
  public_subnet_ids   = module.network.public_subnet_ids
  security_group_ids  = [module.security.alb_sg_id]
  app_port            = var.app_port
  health_check_path   = var.health_check_path
  acm_certificate_arn = var.acm_certificate_arn
  route53_zone_id     = var.route53_zone_id
  domain_name         = var.domain_name
  deletion_protection = var.alb_deletion_protection
  account_id          = data.aws_caller_identity.current.account_id
  is_prod             = local.is_prod
}

module "ecs" {
  source = "./modules/ecs"

  name_prefix = local.name_prefix
  aws_region  = var.aws_region
  account_id  = data.aws_caller_identity.current.account_id
  is_prod     = local.is_prod

  private_subnet_ids      = module.network.private_subnet_ids
  security_group_ids      = [module.security.app_sg_id]
  target_group_arn        = module.alb.target_group_arn
  alb_arn_suffix          = module.alb.arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  image              = "${module.ecr.repository_url}:${var.image_tag}"
  app_port           = var.app_port
  task_cpu           = var.task_cpu
  task_memory        = var.task_memory
  desired_count      = var.desired_count
  min_capacity       = var.autoscaling_min_capacity
  max_capacity       = var.autoscaling_max_capacity
  use_fargate_spot   = var.use_fargate_spot
  log_retention_days = var.log_retention_days

  environment_variables = {
    RAILS_ENV                = "production"
    RACK_ENV                 = "production"
    RAILS_LOG_TO_STDOUT      = "true"
    RAILS_SERVE_STATIC_FILES = "true"
    RAILS_MAX_THREADS        = tostring(var.rails_max_threads)
    WEB_CONCURRENCY          = tostring(max(1, floor(var.task_cpu / 1024)))
    PORT                     = tostring(var.app_port)
    AWS_REGION               = var.aws_region
    ACTIVE_STORAGE_BUCKET    = module.storage.bucket_name
    APP_HOST                 = local.app_host
    APP_PROTOCOL             = local.app_scheme
    MALLOC_ARENA_MAX         = "2"
  }

  # `arn:json-key::` の形で JSON の 1 キーだけを取り出せる
  secrets = {
    DATABASE_URL     = "${module.database.secret_arn}:url::"
    RAILS_MASTER_KEY = aws_secretsmanager_secret.rails_master_key.arn
  }

  secret_arns = [
    module.database.secret_arn,
    aws_secretsmanager_secret.rails_master_key.arn,
  ]
  s3_bucket_arn = module.storage.bucket_arn
}

module "monitoring" {
  source = "./modules/monitoring"

  name_prefix              = local.name_prefix
  alarm_email              = var.alarm_email
  aws_region               = var.aws_region
  alb_arn_suffix           = module.alb.arn_suffix
  target_group_arn_suffix  = module.alb.target_group_arn_suffix
  ecs_cluster_name         = module.ecs.cluster_name
  ecs_service_name         = module.ecs.service_name
  db_instance_id           = module.database.instance_id
  db_allocated_storage_gib = var.db_allocated_storage
}
