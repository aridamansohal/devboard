# Show the S3 bucket name used for Terraform remote state.
output "state_bucket_name" {
  description = "Terraform state S3 bucket name."
  value       = aws_s3_bucket.state.id
}

# Show the bucket ARN for reference and future IAM policies.
output "state_bucket_arn" {
  description = "Terraform state S3 bucket ARN."
  value       = aws_s3_bucket.state.arn
}

# Generate the backend configuration for the main Terraform project.
# Run: terraform output -raw backend_hcl > ../backend.hcl
output "backend_hcl" {
  description = "S3 backend configuration for the main Terraform project."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    key          = "devboard/terraform.tfstate"
    region       = "${var.region}"
    encrypt      = true
    use_lockfile = true
  EOT
}