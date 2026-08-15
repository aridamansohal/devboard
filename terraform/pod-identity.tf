# ============================================================
# VPC CNI Pod Identity
# ============================================================
resource "aws_iam_role" "vpc_cni" {
  name = "devboard-vpc_cni"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# Allows the EBS CSI driver to manage AWS EBS volumes.
resource "aws_iam_role_policy_attachment" "vpc_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.vpc_cni.arn
}



# ============================================================
# EBS CSI Pod Identity
# ============================================================
# Dedicated IAM role for the EBS CSI driver.
# The role is used through EKS Pod Identity instead of the worker-node role.
resource "aws_iam_role" "ebs_csi" {
  name = "devboard-ebs-csi"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# Allows the EBS CSI driver to manage AWS EBS volumes.
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# Connects the EBS CSI ServiceAccount to its dedicated IAM role.
resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
}


# ============================================================
# External Secrets Pod Identity
# ============================================================
# Dedicated IAM role for External Secrets Operator.
# The role is used through EKS Pod Identity so the operator
# can access AWS Secrets Manager without giving permissions to worker nodes.
resource "aws_iam_role" "external_secrets" {
  name = "devboard-external-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

# Allows External Secrets Operator to read DevBoard secrets
# from AWS Secrets Manager.

resource "aws_iam_policy" "external_secrets" {
  name = "devboard-external-secrets"
  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]

        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:devboard/*"
      }
    ]

  })

}


# Attaches the External Secrets permissions to its dedicated IAM role.
resource "aws_iam_role_policy_attachment" "external_secrets_policy" {
  policy_arn = aws_iam_policy.external_secrets.arn
  role       = aws_iam_role.external_secrets.name
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "external-secrets"
  service_account = "external-secrets"
  role_arn        = aws_iam_role.external_secrets.arn
}