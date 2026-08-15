module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.cluster_name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  # If its AZ fails, private-subnet internet egress is lost.
  # Cost-saving choice for this learning project; not recommended for production.
  single_nat_gateway = true

  enable_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  # Kubernetes uses these tags to discover subnets for load balancers. see README.md for details and reference.
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = local.tags
}