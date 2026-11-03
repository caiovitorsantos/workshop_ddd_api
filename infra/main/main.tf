module "network" {
  source = "./modules/network"

  name = var.project
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "eks" {
  source = "./modules/eks"

  name                = var.project
  kubernetes_version  = var.kubernetes_version
  role_arn            = data.aws_iam_role.labrole.arn
  subnet_ids          = module.network.public_subnet_ids
  node_instance_type  = var.node_instance_type
  admin_principal_arn = var.admin_principal_arn
}

module "database" {
  source = "./modules/database"

  name                      = var.project
  vpc_id                    = module.network.vpc_id
  subnet_ids                = module.network.private_subnet_ids
  allowed_security_group_id = module.eks.cluster_security_group_id
  password                  = var.db_password
}

module "registry" {
  source = "./modules/registry"

  name = var.project
}
