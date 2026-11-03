# Remote state in the bucket created by infra/bootstrap. The bucket name has the
# account id in it, so it is passed at init time (partial configuration):
#
#   terraform init -backend-config="bucket=oficina-api-tfstate-<account-id>"
terraform {
  backend "s3" {
    key          = "oficina-api/main.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # S3-native locking, no DynamoDB table
  }
}
