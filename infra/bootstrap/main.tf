# Run once per AWS account, locally, before anything else:
#
#   cd infra/bootstrap && terraform init && terraform apply
#
# Creates the S3 bucket that holds infra/main's state. Its own state stays
# local on purpose: it is one bucket, and it cannot store itself in a bucket
# that does not exist yet. Locking uses S3's native lockfile (Terraform 1.10+),
# so no DynamoDB table.
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}

data "aws_caller_identity" "current" {}

# Bucket names are global: the account id keeps this one unique.
resource "aws_s3_bucket" "tfstate" {
  bucket = "oficina-api-tfstate-${data.aws_caller_identity.current.account_id}"
}

# Every state write is kept: a bad apply can be rolled back to the last good
# state file.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State holds the database password in plain text: never public.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket" {
  description = "Pass to infra/main: terraform init -backend-config=\"bucket=<this>\""
  value       = aws_s3_bucket.tfstate.bucket
}
