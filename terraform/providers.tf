# AWS provider configuration.
provider "aws" {
  region = var.region
}


# AWS account information used by IAM policies and ARNs.
data "aws_caller_identity" "current" {}


# Available Availability Zones in the selected AWS region.
data "aws_availability_zones" "available" {
  state = "available"
}



data "aws_eks_cluster" "devboard" {
  name = "devboard"
}

provider "helm" {
  kubernetes = {
    host = aws_eks_cluster.this.endpoint

    cluster_ca_certificate = base64decode(
      aws_eks_cluster.this.certificate_authority[0].data
    )

    exec = {
      api_version = "client.authentication.k8s.io/v1"
      command     = "aws"

      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.this.name,
        "--region",
        var.region
      ]
    }
  }
}
provider "kubernetes" {
  host = aws_eks_cluster.this.endpoint

  cluster_ca_certificate = base64decode(
    aws_eks_cluster.this.certificate_authority[0].data
  )

  exec {
    api_version = "client.authentication.k8s.io/v1"
    command     = "aws"

    args = [
      "eks",
      "get-token",
      "--cluster-name",
      aws_eks_cluster.this.name,
      "--region",
      var.region
    ]
  }
}