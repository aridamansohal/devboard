resource "aws_iam_role" "cluster" {
  name = "eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}


resource "aws_eks_cluster" "this" {
  name = var.cluster_name

  # API authentication
  # → How IAM identities get into EKS

  # Bootstrap cluster creator admin
  # → The person/role that creates the cluster gets admin access

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  bootstrap_self_managed_addons = false

  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = module.vpc.private_subnets
    endpoint_public_access  = true
    endpoint_private_access = true
  }

  # Enable EKS control-plane logs for troubleshooting and auditing.
  enabled_cluster_log_types = [
    "audit",
    "authenticator"
  ]

  # Ensure that IAM Role permissions are created before and deleted
  # after EKS Cluster handling. Otherwise, EKS will not be able to
  # properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.eks_cluster
  ]
}

# List: ["vpc-cni", "coredns"] → ordered, uses indexes (0, 1)
# Set:  ["vpc-cni", "coredns"] → unique values, no indexes
# With a set, each.value and each.key are the same: "vpc-cni" → "vpc-cni"


resource "aws_eks_addon" "this" {
  for_each     = toset(local.eks_addons)
  cluster_name = aws_eks_cluster.this.name
  addon_name   = each.value

}

