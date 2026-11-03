variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  description = "Prefix of every resource name."
  type        = string
  default     = "oficina-api"
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "db_password" {
  description = "Master password of the RDS instance. In CI: the TF_VAR_db_password secret."
  type        = string
  sensitive   = true
}

variable "admin_principal_arn" {
  description = <<-EOT
    Extra IAM principal to make cluster admin (the course's access entry).
    Optional: whoever creates the cluster is admin already, and in AWS Academy
    the CD runs with that same lab role.
  EOT
  type        = string
  default     = null
}
