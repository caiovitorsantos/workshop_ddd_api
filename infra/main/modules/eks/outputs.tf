output "cluster_name" {
  value = aws_eks_cluster.this.name
}

# EKS attaches this group to the control plane and to managed nodes; the
# database admits traffic from it.
output "cluster_security_group_id" {
  value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
