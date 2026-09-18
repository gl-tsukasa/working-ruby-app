locals {
  container_name = "web"

  env_list = [
    for k, v in var.environment_variables : { name = k, value = v }
  ]
  secret_list = [
    for k, v in var.secrets : { name = k, valueFrom = v }
  ]

  base_container = {
    image       = var.image
    essential   = true
    environment = local.env_list
    secrets     = local.secret_list

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.app.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "ecs"
      }
    }

    linuxParameters = {
      initProcessEnabled = true # ECS Exec で必要
    }

    readonlyRootFilesystem = false # Rails は tmp/ に書く
    ulimits = [
      { name = "nofile", softLimit = 65536, hardLimit = 65536 }
    ]
  }
}

############################################
# Cluster
############################################
resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 1
  }
}

############################################
# Logs
############################################
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.name_prefix}/web"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "migrate" {
  name              = "/ecs/${var.name_prefix}/migrate"
  retention_in_days = var.log_retention_days
}

############################################
# Task definitions
############################################
resource "aws_ecs_task_definition" "web" {
  family                   = "${var.name_prefix}-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(local.base_container, {
      name    = local.container_name
      command = ["bin/rails", "server", "-b", "0.0.0.0", "-p", tostring(var.app_port)]
      portMappings = [{
        containerPort = var.app_port
        hostPort      = var.app_port
        protocol      = "tcp"
      }]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -fsS http://localhost:${var.app_port}/ -o /dev/null || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    })
  ])
}

# db:migrate 用 (CI から run-task で起動)
resource "aws_ecs_task_definition" "migrate" {
  family                   = "${var.name_prefix}-migrate"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    merge(local.base_container, {
      name    = "migrate"
      command = ["bin/rails", "db:prepare"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.migrate.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    })
  ])
}

############################################
# Service
############################################
resource "aws_ecs_service" "web" {
  name            = "${var.name_prefix}-web"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = var.desired_count

  platform_version                  = "LATEST"
  enable_execute_command            = true
  health_check_grace_period_seconds = 90
  propagate_tags                    = "SERVICE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  # Spot を使う場合: base 1 台は On-Demand、残りは Spot:On-Demand = 3:1
  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 1
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [1] : []
    content {
      capacity_provider = "FARGATE_SPOT"
      weight            = 3
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = var.use_fargate_spot ? [] : [1]
    content {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 0
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = local.container_name
    container_port   = var.app_port
  }

  lifecycle {
    # オートスケールが desired_count を動かすので差分にしない
    ignore_changes = [desired_count]
  }

  depends_on = [aws_ecs_cluster_capacity_providers.this]
}

############################################
# Auto Scaling
############################################
resource "aws_appautoscaling_target" "web" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.web.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.name_prefix}-web-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "requests" {
  name               = "${var.name_prefix}-web-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = 500 # 1 タスクあたり 500 req/min を目安
    scale_in_cooldown  = 300
    scale_out_cooldown = 60

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${var.target_group_arn_suffix}"
    }
  }
}

# 夜間はスケールインさせる (prod 以外)
resource "aws_appautoscaling_scheduled_action" "night_scale_in" {
  count = var.is_prod ? 0 : 1

  name               = "${var.name_prefix}-night-scale-in"
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  schedule           = "cron(0 13 ? * MON-FRI *)" # 22:00 JST
  timezone           = "UTC"

  scalable_target_action {
    min_capacity = 1
    max_capacity = 1
  }
}

resource "aws_appautoscaling_scheduled_action" "morning_scale_out" {
  count = var.is_prod ? 0 : 1

  name               = "${var.name_prefix}-morning-scale-out"
  service_namespace  = aws_appautoscaling_target.web.service_namespace
  resource_id        = aws_appautoscaling_target.web.resource_id
  scalable_dimension = aws_appautoscaling_target.web.scalable_dimension
  schedule           = "cron(0 23 ? * SUN-THU *)" # 08:00 JST (翌日)
  timezone           = "UTC"

  scalable_target_action {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }
}
