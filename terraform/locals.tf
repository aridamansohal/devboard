locals {
  # VPC configuration.
  vpc_cidr = "10.0.0.0/16"

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets = [
    "10.0.0.0/20",
    "10.0.16.0/20"
  ]

  private_subnets = [
    "10.0.64.0/20",
    "10.0.80.0/20"
  ]

  intra_subnets = [
    "10.0.128.0/20",
    "10.0.144.0/20"
  ]


  # Common tags used across the infrastructure.
  tags = {
    Project   = "devboard"
    ManagedBy = "terraform"
  }


  # EKS managed add-ons installed by Terraform.
  eks_addons = [
    "vpc-cni",
    "coredns",
    "kube-proxy",
    "eks-pod-identity-agent",
    "aws-ebs-csi-driver",
    "metrics-server"

  ]


  # CNI permissions are intentionally NOT attached to the node role.
  # VPC CNI permissions are handled separately using Pod Identity.
  node_policy_arns = [
    # Allows the EC2 worker node to function as an EKS worker.
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",

    # Allows the worker node to pull container images from Amazon ECR.
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}