terraform {
  # Terraform version required by this project.
  # Our machine currently has Terraform 1.15.8.
  required_version = ">= 1.11.0"

  # Providers are plugins that allow Terraform
  # to communicate with external platforms.
  required_providers {

    # AWS provider:
    # Allows Terraform to create/manage AWS resources.
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

    # Helm provider:
    # Will allow Terraform to manage Helm releases
    # later when we deploy applications to EKS.
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }

    # Kubernetes provider:
    # Will allow Terraform to communicate with the
    # Kubernetes API later when we work with EKS.
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
  }
}