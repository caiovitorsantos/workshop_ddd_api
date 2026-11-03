# EKS cluster and managed node group, after the course's Terraform lesson 8 —
# with LabRole in place of the IAM roles the lesson creates (AWS Academy does
# not allow creating roles).
resource "aws_eks_cluster" "this" {
  name     = var.name
  version  = var.kubernetes_version
  role_arn = var.role_arn

  vpc_config {
    subnet_ids = var.subnet_ids
  }

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    # Whoever runs the apply (the lab role, locally or in the CD) is admin.
    bootstrap_cluster_creator_admin_permissions = true
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-nodes"
  node_role_arn   = var.role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = [var.node_instance_type]

  # Room for the HPA's 6 API replicas plus worker, Mailpit and system pods.
  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }
}

# The HPA reads CPU and memory from metrics-server; without it the
# autoscaler shows <unknown> and never scales.
resource "aws_eks_addon" "metrics_server" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "metrics-server"

  # Add-ons schedule pods: they need nodes to exist first.
  depends_on = [aws_eks_node_group.this]
}

# The course's access entry, for an extra admin besides the cluster creator.
resource "aws_eks_access_entry" "admin" {
  count = var.admin_principal_arn == null ? 0 : 1

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  count = var.admin_principal_arn == null ? 0 : 1

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}
