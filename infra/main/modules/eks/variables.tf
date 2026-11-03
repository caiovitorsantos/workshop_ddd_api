variable "name" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "role_arn" {
  description = "IAM role for both the cluster and the nodes (LabRole in AWS Academy)."
  type        = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "node_instance_type" {
  type = string
}

variable "admin_principal_arn" {
  type    = string
  default = null
}
