# # ============================================================
# # EKS Access
# # ============================================================

# # Allows the IAM identity running Terraform to authenticate
# # to the EKS cluster as a cluster administrator.

# resource "aws_eks_access_entry" "example" {
#   cluster_name  = aws_eks_cluster.this.name
#   principal_arn = var.access_principal_arn
#   type          = "STANDARD"
# }

# # Grants the cluster creator full administrative access to EKS.
# resource "aws_eks_access_policy_association" "example" {
#   cluster_name  = aws_eks_cluster.this.name
#   policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
#   principal_arn = var.access_principal_arn

#   access_scope {
#     type = "cluster"
#   }
# }