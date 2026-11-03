# AWS Academy forbids creating IAM roles. Cluster and nodes use the lab's
# pre-existing LabRole instead of the roles the course's lesson 8 creates.
data "aws_iam_role" "labrole" {
  name = "LabRole"
}

data "aws_availability_zones" "available" {
  state = "available"
}
