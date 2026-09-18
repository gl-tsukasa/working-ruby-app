variable "name_prefix" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "single_nat_gateway" { type = bool }
variable "enable_vpc_endpoints" { type = bool }
variable "log_retention_days" { type = number }
