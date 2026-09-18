variable "name_prefix" { type = string }
variable "account_id" { type = string }
variable "is_prod" { type = bool }
variable "allowed_origins" {
  description = "Active Storage direct upload 用 CORS の許可オリジン"
  type        = list(string)
  default     = []
}
