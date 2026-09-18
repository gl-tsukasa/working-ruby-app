variable "name_prefix" { type = string }
variable "vpc_id" { type = string }
variable "app_port" { type = number }
variable "db_port" {
  type    = number
  default = 5432
}
