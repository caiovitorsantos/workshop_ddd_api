# Read by the CD to fill the ConfigMap/Secret and push the image.
output "region" {
  value = var.region
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "ecr_repository_url" {
  value = module.registry.repository_url
}

output "db_host" {
  value = module.database.address
}

output "db_name" {
  value = module.database.db_name
}

output "db_username" {
  value = module.database.username
}
