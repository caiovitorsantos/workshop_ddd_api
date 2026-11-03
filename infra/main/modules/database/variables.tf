variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets in at least two AZs."
  type        = list(string)
}

variable "allowed_security_group_id" {
  description = "Security group whose members may open connections on 5432."
  type        = string
}

variable "engine_version" {
  description = "Major version; RDS picks the current minor. Fall back to 16 if Academy lacks 17."
  type        = string
  default     = "17"
}

variable "db_name" {
  type    = string
  default = "oficina_api_production"
}

variable "username" {
  type    = string
  default = "oficina"
}

variable "password" {
  type      = string
  sensitive = true
}
