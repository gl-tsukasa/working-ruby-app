############################################
# ALB
############################################
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb"
  description = "ALB: HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-alb" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "To ECS tasks"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

############################################
# ECS tasks
############################################
resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app"
  description = "ECS tasks: app port from ALB only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-app" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "From ALB"
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound (NAT / VPC endpoints)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

############################################
# RDS
############################################
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db"
  description = "RDS: PostgreSQL from ECS tasks only"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name_prefix}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from app"
  from_port                    = var.db_port
  to_port                      = var.db_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}
