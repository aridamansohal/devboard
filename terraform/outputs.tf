# ============================================================
# VPC Outputs
# ============================================================

output "vpc_id" {
  description = "ID of the DevBoard VPC"
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "intra_subnets" {
  description = "IDs of the intra subnets"
  value       = module.vpc.intra_subnets
}


# ============================================================
# EKS Outputs
# ============================================================

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS Kubernetes API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}



# ============================================================
# EKS Node Group Outputs
# ============================================================

output "node_group_name" {
  description = "Name of the EKS managed node group"
  value       = aws_eks_node_group.node_group.node_group_name
}

output "node_group_arn" {
  description = "ARN of the EKS managed node group"
  value       = aws_eks_node_group.node_group.arn
}


# ============================================================
# IAM Outputs
# ============================================================

output "cluster_role_arn" {
  description = "ARN of the IAM role used by the EKS control plane"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "ARN of the IAM role used by EKS worker nodes"
  value       = aws_iam_role.this.arn
}

output "ebs_csi_role_arn" {
  description = "ARN of the IAM role used by the EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role used by External Secrets Operator"
  value       = aws_iam_role.external_secrets.arn
}


# ============================================================
# Logging
# ============================================================

output "eks_log_group_name" {
  description = "CloudWatch log group used for EKS control-plane logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}