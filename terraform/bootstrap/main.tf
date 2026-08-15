# Get the current AWS account ID so the S3 bucket name can be unique.
data "aws_caller_identity" "current" {}

# Use the custom bucket name when provided; if null, generate one automatically.
# Example: "my-state-bucket" → uses it; null → "devboard-tfstate-<account-id>-<region>".
locals {
  bucket_name = coalesce(
    var.bucket_name,
    "devboard-tfstate-${data.aws_caller_identity.current.account_id}-${var.region}"
  )
}

# Create the S3 bucket that will store Terraform remote state.
resource "aws_s3_bucket" "state" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Project   = "devboard"
    ManagedBy = "terraform"
    Purpose   = "terraform-state"
  }
}

# Ensure the bucket owner owns all objects and disable S3 ACLs.
resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Keep previous Terraform state versions so accidental changes can be recovered.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt Terraform state at rest using S3-managed AES256 encryption.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Prevent the Terraform state bucket from being accessed publicly.
resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Automatically clean up old state versions and abandoned multipart uploads.
resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    # Delete old state versions after 30 days.
    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Remove incomplete multipart uploads after 7 days.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Allow access to the state bucket only over HTTPS.
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"

        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]

        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}