# AWS region where the DevBoard infrastructure will be deployed.
variable "region" {
  description = "AWS region for DevBoard infrastructure."
  type        = string
  default     = "us-west-2"
}

# Name used for the VPC and later the EKS cluster.
variable "cluster_name" {
  description = "Name used for the DevBoard cluster and VPC."
  type        = string
  default     = "devboard"
}

variable "kubernetes_version" {
  description = "EKS control plane version. Pinned rather than floating so every learner gets the same cluster."
  type        = string
  default     = "1.34"
}

variable "node_instance_type" {
  description = "Worker node instance type. t3.large (2 vCPU / 8 GiB) is the floor once Ollama and the observability stack are running; t3.medium cannot fit them."
  type        = list(string)
  default     = ["t3.medium"]

}

variable "node_desired_size" {
  description = "Nodes to run. 3 fits both DevBoard stacks plus Ollama plus observability. Drop to 2 to save ~$61/month, but then run only one DevBoard stack."
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum nodes"
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum nodes"
  type        = number
  default     = 4
}

variable "node_disk_size" {
  description = "Root volume per node, GiB. 30 rather than 20: Ollama's ~1.3 GB model plus three app images plus the ArgoCD/ESO/Envoy control planes get close to disk-pressure eviction on 20."
  type        = number
  default     = 30
}

variable "ami_type" {
  description = "AMI type used by the EKS managed node group."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

# variable "access_principal_arn" {
#   description = "IAM role ARN used to demonstrate EKS Access Entry and Access Policy."
#   type        = string
# }

variable "enable_argocd" {
  description = "Install ArgoCD via Helm from Terraform. Set false if you would rather install it by hand (the flow in gitops/05-argocd.md)."
  type        = bool
  default     = true
}

variable "argocd_chart_version" {
  description = "argo-cd Helm chart version. Pinned so a cluster built today matches one built next month."
  type        = string
  default     = "10.3.0"
}