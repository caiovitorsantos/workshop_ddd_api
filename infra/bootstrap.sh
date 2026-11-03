#!/usr/bin/env bash
# Creates the S3 bucket that holds infra/main's Terraform state. Run once per
# AWS account, before the first `terraform init` (re-running is harmless):
#
#   infra/bootstrap.sh
#
# A script and not Terraform: AWS Academy's service control policy denies
# s3:GetBucketObjectLockConfiguration, which the AWS provider reads on every
# refresh of an aws_s3_bucket — so Terraform cannot manage this bucket there.
set -euo pipefail

region="${AWS_REGION:-us-east-1}"
account=$(aws sts get-caller-identity --query Account --output text)
bucket="oficina-api-tfstate-${account}"

if aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
  echo "bucket $bucket already exists"
else
  # us-east-1 is the one region that rejects a LocationConstraint.
  if [ "$region" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$bucket" --region "$region" >/dev/null
  else
    aws s3api create-bucket --bucket "$bucket" --region "$region" \
      --create-bucket-configuration LocationConstraint="$region" >/dev/null
  fi
  echo "bucket $bucket created"
fi

# Every state write is kept: a bad apply can be rolled back to the last good
# state file.
aws s3api put-bucket-versioning --bucket "$bucket" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption --bucket "$bucket" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# The state holds the database password in plain text: never public.
aws s3api put-public-access-block --bucket "$bucket" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "next: cd infra/main && terraform init -backend-config=\"bucket=${bucket}\""
