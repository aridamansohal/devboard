# Terraform Bootstrap

Bootstrap for creating the S3 bucket used by the main Terraform project for remote state.

The bootstrap is kept separate because the S3 backend must exist before the main Terraform configuration can use it.

## Structure

bootstrap/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── README.md

## What It Creates

The bootstrap creates and secures the Terraform state bucket with:

- S3 versioning
- Server-side encryption
- Public access blocking
- Bucket owner enforced object ownership
- Lifecycle cleanup
- HTTPS-only access
- S3-native Terraform state locking

## Bucket Naming

A custom bucket name can be provided through `bucket_name`.

If no custom name is provided, Terraform generates a unique name using the AWS account ID and region:

devboard-tfstate-<account-id>-<region>

## Usage

Run from the bootstrap directory:

    cd ~/devboard/terraform/bootstrap
    tf init
    tf validate
    tf plan

Review the plan before creating resources.

If the plan is correct:

    tf apply

## Check Outputs

After the bootstrap is applied:

    tf output

The bootstrap provides:

- `state_bucket_name`
- `state_bucket_arn`
- `backend_hcl`

## Generate Backend Configuration

After the S3 state bucket is created:

    tf output -raw backend_hcl > ../backend.hcl

This creates:

    terraform/backend.hcl

The generated backend configuration contains:

    bucket       = "<state-bucket-name>"
    key          = "devboard/terraform.tfstate"
    region       = "<region>"
    encrypt      = true
    use_lockfile = true

## State Locking

The main Terraform project uses S3-native state locking.

Terraform stores the state and lock separately:

    S3 State Bucket
    ├── devboard/terraform.tfstate
    └── devboard/terraform.tfstate.tflock

The lock file prevents multiple Terraform operations from modifying the same state at the same time.

## Bootstrap Flow

    Bootstrap
        |
        v
    Create S3 State Bucket
        |
        v
    Generate backend.hcl
        |
        v
    Configure Main Terraform Backend
        |
        v
    Main Terraform
        |
        v
    S3 Remote State + Locking

## Important

The bootstrap initially uses local Terraform state because the S3 state bucket does not exist yet.

The bootstrap creates the S3 bucket first.

The main Terraform project then uses that S3 bucket as its remote backend.

## Reference

This bootstrap uses the DevBoard `mega-project` as the reference architecture while keeping the implementation simple and focused on this project.

## Documentation

Terraform S3 Backend:
https://developer.hashicorp.com/terraform/language/backend/s3

Terraform State Locking:
https://developer.hashicorp.com/terraform/language/state/locking

Amazon S3:
https://docs.aws.amazon.com/s3/
