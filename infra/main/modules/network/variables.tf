variable "name" {
  type = string
}

variable "azs" {
  description = "At least two availability zones."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "EKS and RDS need subnets in at least two availability zones."
  }
}
