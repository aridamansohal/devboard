variable "region" {
  description = "AWS region where the Terraform state bucket will be created."
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "Optional custom S3 bucket name for Terraform state."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Allow the state bucket to be destroyed even when it contains objects."
  type        = bool
  default     = false
}