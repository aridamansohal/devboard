# DevBoard — AWS EKS Infrastructure with Terraform

> A hands-on EKS project built with Terraform, with the infrastructure, troubleshooting decisions, and lessons learned documented in one place.

---

## Table of Contents

- [1. Project Overview](#1-project-overview)
- [2. Architecture](#2-architecture)
- [3. Current Environment](#3-current-environment)
- [4. Terraform Structure](#4-terraform-structure)
- [5. VPC and Networking](#5-vpc-and-networking)
- [6. EKS Cluster](#6-eks-cluster)
- [7. EKS Authentication](#7-eks-authentication)
- [8. Managed Node Group](#8-managed-node-group)
- [9. EKS Add-ons](#9-eks-add-ons)
- [10. EKS Pod Identity](#10-eks-pod-identity)
- [11. VPC CNI](#11-vpc-cni)
- [12. EBS CSI and Persistent Storage](#12-ebs-csi-and-persistent-storage)
- [13. Kubernetes Provider](#13-kubernetes-provider)
- [14. CloudWatch Logging](#14-cloudwatch-logging)
- [15. Terraform Outputs](#15-terraform-outputs)
- [16. Deploy and Verify](#16-deploy-and-verify)
- [17. Problems We Faced and How We Fixed Them](#17-problems-we-faced-and-how-we-fixed-them)
- [18. Troubleshooting Runbook](#18-troubleshooting-runbook)
- [19. Final Verified State](#19-final-verified-state)
- [20. Lessons Learned](#20-lessons-learned)
- [21. Project Checkpoint](#21-project-checkpoint)
- [22. Next Phase](#22-next-phase)

---

# 1. Project Overview

DevBoard is a practical AWS/EKS learning project. The infrastructure is intentionally separated into logical Terraform files so that each layer can be understood instead of hiding the entire environment behind one large configuration.

The project currently covers:

- AWS VPC and subnet design
- Public/private networking
- NAT Gateway connectivity
- Amazon EKS
- EKS API authentication
- EKS managed node groups
- IAM roles and policies
- EKS Pod Identity
- VPC CNI
- CoreDNS
- kube-proxy
- EKS Pod Identity Agent
- AWS EBS CSI Driver
- Metrics Server
- Kubernetes StorageClass
- gp3 persistent storage
- EKS control-plane logging
- Terraform outputs
- Troubleshooting and verification

---

# 2. Architecture

## High-level architecture

```text
                              AWS
                               │
                               ▼
                         ┌───────────┐
                         │    VPC    │
                         └─────┬─────┘
                               │
                  ┌────────────┴────────────┐
                  │                         │
            Public Subnets            Private Subnets
                  │                         │
          Internet Gateway             EKS Nodes
                  │                         │
             NAT Gateway                    │
                                            ▼
                                      ┌───────────┐
                                      │    EKS    │
                                      │  devboard │
                                      └─────┬─────┘
                                            │
             ┌──────────────────────────────┼────────────────────────┐
             │                              │                        │
          VPC CNI                       CoreDNS                kube-proxy
             │
             │ Pod Identity
             ▼
      VPC CNI IAM Role
             │
      AmazonEKS_CNI_Policy

             ┌──────────────────────────────┐
             │ EKS Pod Identity Agent       │
             └──────────────┬───────────────┘
                            │
                  ┌─────────┴──────────┐
                  │                    │
               EBS CSI          External Secrets
                  │
             Pod Identity
                  │
            EBS CSI IAM Role
                  │
       AmazonEBSCSIDriverPolicy
                  │
                  ▼
             EBS CSI Driver
                  │
                  ▼
           gp3 StorageClass
                  │
                  ▼
          Encrypted EBS Volumes
```

## Traffic/networking concept

Worker nodes live in private subnets. The public subnets provide the public-side network path and NAT Gateway connectivity for outbound access from private resources.

The important distinction is:

```text
Public subnet
    ↓
Internet Gateway / NAT path

Private subnet
    ↓
EKS worker nodes
```

The EKS control-plane endpoint is configured with both public and private access.

---

# 3. Current Environment

| Item | Current value |
|---|---|
| Cluster | `devboard` |
| AWS Region | `us-west-2` |
| Kubernetes version | `1.34` |
| Node group | `devboard-ng` |
| Instance type | `t3.medium` |
| AMI | `AL2023_x86_64_STANDARD` |
| Desired nodes | `3` |
| Minimum nodes | `2` |
| Maximum nodes | `4` |
| EKS authentication | `API` |
| Cluster creator admin | Enabled |
| EKS endpoint | Public + Private |
| Default StorageClass | `gp3` |
| EBS volume type | `gp3` |
| EBS encryption | Enabled |
| CloudWatch log retention | `7 days` |

---

# 4. Terraform Structure

The Terraform configuration is split by responsibility.

```text
terraform/
│
├── providers.tf
├── variables.tf
├── locals.tf
├── vpc.tf
├── iam.tf
├── eks.tf
├── eks_ng.tf
├── podidentity.tf
├── logging.tf
├── storage.tf
├── outputs.tf
└── ...
```

| File | Responsibility |
|---|---|
| `providers.tf` | Terraform, AWS and Kubernetes provider configuration |
| `variables.tf` | Input variables |
| `locals.tf` | Local values and common configuration |
| `vpc.tf` | VPC/network configuration |
| `iam.tf` | EKS/node IAM roles and policies |
| `eks.tf` | EKS control plane and managed add-ons |
| `eks_ng.tf` | EKS managed node group |
| `podidentity.tf` | Pod Identity roles and associations |
| `logging.tf` | EKS CloudWatch logging |
| `storage.tf` | Kubernetes `gp3` StorageClass |
| `outputs.tf` | Important infrastructure outputs |

### Why split the files?

The files are separated by responsibility, not because Terraform requires it. Terraform reads all `.tf` files in the directory as one configuration.

The split makes the project easier to understand:

```text
Network
  ↓
IAM
  ↓
EKS
  ↓
Nodes
  ↓
Pod Identity
  ↓
Storage
  ↓
Kubernetes workloads
```

---

# 5. VPC and Networking

The EKS worker nodes use private subnets.

The network is conceptually:

```text
Internet
   │
   ▼
Internet Gateway
   │
   ▼
Public Subnets
   │
   ▼
NAT Gateway
   │
   ▼
Private Subnets
   │
   ▼
EKS Worker Nodes
```

The private subnets are also tagged for Kubernetes/AWS load-balancer discovery. The project uses tags such as:

```text
kubernetes.io/role/internal-elb = 1
```

This is important later when Kubernetes services require AWS load-balancer integration.

---

# 6. EKS Cluster

The cluster is:

```text
Name:    devboard
Region:  us-west-2
Version: 1.34
```

The cluster uses API-based authentication:

```hcl
access_config {
  authentication_mode                         = "API"
  bootstrap_cluster_creator_admin_permissions = true
}
```

The endpoint is configured with:

```text
endpoint_public_access  = true
endpoint_private_access = true
```

## Why API authentication?

EKS API authentication allows access to be managed through the EKS access model instead of relying on the older `aws-auth` ConfigMap approach for the primary access mechanism.

## Cluster creator permissions

```hcl
bootstrap_cluster_creator_admin_permissions = true
```

This gives the identity that creates the cluster initial administrator access.

This is especially useful for this learning environment because it prevents the cluster creator from immediately losing access after cluster creation.

---

# 7. EKS Authentication

## The access-entry confusion we encountered

We initially considered using an STS session ARN similar to:

```text
arn:aws:sts::ACCOUNT:assumed-role/ROLE/SESSION
```

That is not the stable IAM principal we want to hard-code as an EKS access principal.

The important distinction is:

```text
IAM role / principal
        ↓
EKS access configuration

not

Temporary STS session
        ↓
Hard-coded EKS principal
```

For the cluster creator, the current project uses:

```hcl
bootstrap_cluster_creator_admin_permissions = true
```

For additional users or roles, use stable IAM principal ARNs with EKS access entries.

## Configuring kubectl

After the cluster was created, `kubectl` initially failed with:

```text
http://localhost:8080
connection refused
```

That did not mean the EKS cluster itself was down. It meant the local machine did not have the correct Kubernetes context configured.

Fix:

```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name devboard
```

Verify:

```bash
kubectl config current-context
kubectl get nodes
```

The important mental model is:

```text
AWS EKS cluster
      ↓
update-kubeconfig
      ↓
local kubeconfig
      ↓
kubectl context
      ↓
EKS Kubernetes API
```

---

# 8. Managed Node Group

The managed node group is:

```text
Name:           devboard-ng
Instance type:  t3.medium
AMI:            AL2023_x86_64_STANDARD
Desired:        3
Minimum:        2
Maximum:        4
```

The nodes run in private subnets.

## Node root disk

The launch template configures the node root disk as:

```text
Type:                 gp3
Size:                 30 GB
Encrypted:            true
Delete on termination true
EBS optimized:        true
```

### Important: node gp3 vs Kubernetes gp3

These are two different things:

```text
Launch Template gp3
        ↓
EC2 node operating-system disk

Kubernetes StorageClass gp3
        ↓
Persistent EBS volumes for Kubernetes PVCs
```

Do not confuse the two simply because both use the name `gp3`.

---

# 9. EKS Add-ons

The cluster uses the following add-ons:

```text
coredns
kube-proxy
vpc-cni
eks-pod-identity-agent
aws-ebs-csi-driver
metrics-server
```

The final verified state was:

| Add-on | Status | Health issues |
|---|---|---|
| `vpc-cni` | `ACTIVE` | None |
| `kube-proxy` | `ACTIVE` | None |
| `eks-pod-identity-agent` | `ACTIVE` | None |
| `aws-ebs-csi-driver` | `ACTIVE` | None |
| `metrics-server` | `ACTIVE` | None |
| `coredns` | `ACTIVE` | None |

### Why this matters

A Terraform apply can report problems with an add-on even though the Terraform syntax itself is correct. In our case, the add-on health problem was downstream of unhealthy worker nodes and VPC CNI, so repeatedly retrying the add-on was not the correct fix.

---

# 10. EKS Pod Identity

Pod Identity gives Kubernetes workloads a dedicated AWS identity without putting every AWS permission on the EC2 worker-node role.

The general pattern is:

```text
Kubernetes ServiceAccount
          ↓
EKS Pod Identity
          ↓
Dedicated IAM Role
          ↓
Required AWS permissions
```

The project uses this model for infrastructure components that need AWS permissions.

## VPC CNI

```text
ServiceAccount: aws-node
Namespace:      kube-system
IAM policy:     AmazonEKS_CNI_Policy
```

## EBS CSI

```text
ServiceAccount: ebs-csi-controller-sa
Namespace:      kube-system
IAM policy:     AmazonEBSCSIDriverPolicy
```

## External Secrets

External Secrets also uses a dedicated IAM role and Pod Identity association rather than putting Secrets Manager permissions directly on the worker-node role.

### Why separate roles?

This follows least privilege:

```text
CNI needs CNI permissions
EBS CSI needs EBS permissions
External Secrets needs Secrets Manager permissions

Do not give all of those permissions to every node.
```

---

# 11. VPC CNI

The Amazon VPC CNI is responsible for Kubernetes Pod networking using AWS VPC networking.

Important resources:

```text
Namespace:       kube-system
DaemonSet:       aws-node
ServiceAccount:  aws-node
Label:           k8s-app=aws-node
```

Verification:

```bash
kubectl get pods -n kube-system -l k8s-app=aws-node
```

### What does `-l` mean?

`-l` is a Kubernetes label selector.

```bash
-l k8s-app=aws-node
```

means:

```text
Find resources where:

label key   = k8s-app
label value = aws-node
```

---

# 12. EBS CSI and Persistent Storage

The cluster uses the AWS EBS CSI driver for Kubernetes persistent storage.

The StorageClass is:

```text
gp3
```

Configuration:

| Setting | Value |
|---|---|
| Provisioner | `ebs.csi.aws.com` |
| Volume type | `gp3` |
| Encryption | `true` |
| Filesystem | `ext4` |
| Reclaim policy | `Delete` |
| Binding mode | `WaitForFirstConsumer` |
| Expansion | Enabled |
| Default | Yes |

## Why `ebs.csi.aws.com`?

This identifies the Amazon EBS CSI driver as the Kubernetes storage provisioner.

The project also has the existing `gp2` StorageClass, but `gp3` is explicitly marked as the default.

## Why `WaitForFirstConsumer`?

EBS volumes are Availability-Zone specific.

Without careful binding, Kubernetes could attempt to provision storage in an AZ that does not match the eventual Pod placement.

With `WaitForFirstConsumer`:

```text
PVC created
    ↓
PVC waits
    ↓
Pod is scheduled
    ↓
Kubernetes knows the AZ
    ↓
EBS CSI provisions the volume
    ↓
Volume is created in the appropriate AZ
```

## Why is gp3 the default?

The project intentionally uses gp3 as the preferred StorageClass instead of relying on the older existing gp2 class.

The default annotation is:

```hcl
"storageclass.kubernetes.io/is-default-class" = "true"
```

---

# 13. Kubernetes Provider

Terraform is managing both AWS infrastructure and Kubernetes resources.

For example:

```hcl
resource "kubernetes_storage_class_v1" "gp3" {
  ...
}
```

That resource is sent to the Kubernetes API, not directly to the AWS EC2/EBS API.

Therefore Terraform needs a Kubernetes provider connection to the EKS cluster.

The authentication pattern uses:

```text
EKS endpoint
     +
Cluster CA certificate
     +
aws eks get-token
     ↓
Kubernetes provider
     ↓
EKS Kubernetes API
```

Example pattern:

```hcl
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
```

> The resource names in this example (`aws_eks_cluster.this`, `var.region`) are project-specific names. The provider documentation provides the authentication pattern; our Terraform configuration supplies our own resource references.

### Documentation path

Use the Terraform Kubernetes provider documentation:

```text
Terraform Registry
→ HashiCorp Kubernetes Provider
→ Authentication
→ Exec plugins
```

Reference:

https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#authentication

---

# 14. CloudWatch Logging

The EKS control plane sends selected logs to CloudWatch.

Log group:

```text
/aws/eks/devboard/cluster
```

Enabled log types:

```text
audit
authenticator
```

Retention:

```text
7 days
```

The short retention is intentional for this learning environment to control CloudWatch cost.

---

# 15. Terraform Outputs

`outputs.tf` exposes important values so that we do not have to manually look them up in the AWS console after every apply.

Expected useful outputs include:

```text
VPC ID
Public subnet IDs
Private subnet IDs
Intra subnet IDs
EKS cluster name
EKS endpoint
EKS version
EKS cluster ARN
Cluster security group ID
Node group name
Node group ARN
Cluster IAM role ARN
Node IAM role ARN
EBS CSI IAM role ARN
External Secrets IAM role ARN
EKS CloudWatch log group
AWS region
```

Check outputs:

```bash
terraform output
```

Example use:

```bash
aws eks update-kubeconfig \
  --region "$(terraform output -raw region)" \
  --name "$(terraform output -raw cluster_name)"
```

---

# 16. Deploy and Verify

## Step 1 — Format

```bash
terraform fmt
```

## Step 2 — Validate

```bash
terraform validate
```

## Step 3 — Review the plan

```bash
terraform plan
```

Always review the plan before applying infrastructure changes.

## Step 4 — Apply

```bash
terraform apply
```

## Step 5 — Configure kubectl

```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name devboard
```

## Step 6 — Verify the context

```bash
kubectl config current-context
```

## Step 7 — Verify nodes

```bash
kubectl get nodes -o wide
```

Expected:

```text
3 nodes
3 × Ready
```

## Step 8 — Verify system Pods

```bash
kubectl get pods -n kube-system -o wide
```

## Step 9 — Verify VPC CNI

```bash
kubectl get pods -n kube-system -l k8s-app=aws-node
```

## Step 10 — Verify StorageClass

```bash
kubectl get storageclass
kubectl describe storageclass gp3
```

## Step 11 — Verify EKS add-ons

```bash
aws eks list-addons \
  --cluster-name devboard \
  --region us-west-2
```

For health details:

```bash
aws eks describe-addon \
  --cluster-name devboard \
  --addon-name coredns \
  --region us-west-2 \
  --query 'addon.{Status:status,Version:addonVersion,Issues:health.issues}'
```

## Step 12 — Verify the node group

```bash
aws eks describe-nodegroup \
  --cluster-name devboard \
  --nodegroup-name devboard-ng \
  --region us-west-2 \
  --query 'nodegroup.{Status:status,Health:health}'
```

---

# 17. Problems We Faced and How We Fixed Them

This is the most important troubleshooting section of the project. The table records the actual failure, what it meant, the fix, and how we verified the fix.

| # | Issue / symptom | What it meant | Fix | Verification |
|---:|---|---|---|---|
| 1 | EKS access principal ARN was confusing | We were considering an STS assumed-role session ARN as a permanent EKS principal | Used cluster-creator bootstrap permissions for the creator; use stable IAM principal ARNs for additional access entries | `kubectl get nodes` works with the configured EKS context |
| 2 | `bootstrap_self_managed_addons` was rejected/misplaced | The setting belongs to the EKS cluster resource, not an individual `aws_eks_addon` resource | Removed it from the add-on resource and kept cluster-level configuration where appropriate | `terraform validate` / `terraform plan` succeeds |
| 3 | `kubectl` tried `localhost:8080` | The local machine did not have the EKS kubeconfig/context | Ran `aws eks update-kubeconfig --region us-west-2 --name devboard` | `kubectl config current-context` and `kubectl get nodes` work |
| 4 | Worker nodes were `NotReady` | The node networking layer was unhealthy | Investigated system Pods, especially `aws-node` | Nodes eventually reported `Ready=True` |
| 5 | `aws-node` was `CrashLoopBackOff` on all 3 nodes | VPC CNI was failing during initialization | Gave the VPC CNI its own IAM role using EKS Pod Identity and `AmazonEKS_CNI_Policy` | `kubectl get pods -n kube-system -l k8s-app=aws-node` shows healthy Pods |
| 6 | `ec2:DescribeNetworkInterfaces` was denied | The VPC CNI did not have the required EC2 API permission | Fixed the CNI Pod Identity role/policy association | VPC CNI became healthy and nodes became `Ready` |
| 7 | VPC CNI namespace/service account was unclear | The values come from Kubernetes resources, not from arbitrary Terraform variables | Verified `kube-system` and `aws-node` | Pod Identity association uses the correct namespace/service account |
| 8 | EKS add-ons showed `DEGRADED` during the initial apply | Add-on health was affected by unhealthy worker nodes/networking | Fixed CNI and node health first instead of repeatedly retrying add-ons | All required add-ons later reported `ACTIVE` with no issues |
| 9 | Node group reported `NodeCreationFailure` | EC2 nodes existed but were not healthy from Kubernetes' point of view | Fixed the underlying VPC CNI/IAM problem | Node group reported `ACTIVE` with no health issues |
| 10 | Kubernetes StorageClass creation tried `localhost` | Terraform's Kubernetes provider was not correctly connected to EKS | Configured the provider with the EKS endpoint, CA certificate and `aws eks get-token` | `kubectl get storageclass` and Terraform resource creation work |
| 11 | Kubernetes provider documentation was hard to find | The relevant authentication information is under provider authentication/exec configuration | Recorded the exact Terraform Registry path in this README | Provider configuration can be traced back to the documented authentication model |
| 12 | `storageclass.kubernetes.io/is-default-class` was confusing | It is a Kubernetes annotation, not a random Terraform setting | Added the annotation to the `gp3` StorageClass | `kubectl get storageclass` shows `gp3` as default |
| 13 | `volume_binding_mode` was confusing | It is a Kubernetes StorageClass field controlling when binding occurs | Used `WaitForFirstConsumer` | `kubectl describe storageclass gp3` confirms the value |
| 14 | `storage_provisioner` was confusing | It identifies the CSI driver that provisions the storage | Used `ebs.csi.aws.com` for the EBS CSI driver | `kubectl describe storageclass gp3` confirms the provisioner |
| 15 | `gp2` was still present | The existing EKS StorageClass was not automatically removed | Kept `gp2`; explicitly made `gp3` the default | `kubectl get storageclass` shows both and `gp3` is default |
| 16 | Node startup showed `InvalidDiskCapacity` | Kubelet temporarily reported image filesystem capacity as 0 | Treated it as a startup warning because the node recovered | `DiskPressure=False` and `Ready=True` |
| 17 | EBS CSI controller showed restarts | A controller restarted during startup | No further change was needed after recovery | Controller was healthy and `6/6 Running` |
| 18 | Useful Terraform outputs were missing | Important resource values were not exposed after apply | Completed `outputs.tf` with cluster, VPC, node-group, IAM, logging and region values | `terraform output` exposes the required values |
| 19 | Terraform `depends_on` behavior was confusing | `depends_on` controls Terraform resource ordering; it does not make an AWS/Kubernetes component healthy | Used dependencies for ordering only and performed separate health verification | AWS and Kubernetes health checks are clean |
| 20 | Kubernetes node names looked unexpected | Node names are based on the EC2/private DNS identity | Confirmed this is normal; the node group remains `devboard-ng` | `kubectl get nodes -o wide` shows the expected EC2-backed nodes |

---

# 18. Troubleshooting Runbook

## A. `kubectl` cannot connect

### Symptom

```text
The connection to the server localhost:8080 was refused
```

### Check

```bash
kubectl config current-context
kubectl config get-contexts
```

### Fix

```bash
aws eks update-kubeconfig \
  --region us-west-2 \
  --name devboard
```

Then:

```bash
kubectl get nodes
```

---

## B. Nodes are `NotReady`

Start with:

```bash
kubectl get nodes
```

Then:

```bash
kubectl describe node <node-name>
```

Then check system Pods:

```bash
kubectl get pods -n kube-system -o wide
```

Because the VPC CNI is fundamental to Pod networking, check it early:

```bash
kubectl get pods -n kube-system -l k8s-app=aws-node
```

If `aws-node` is failing, inspect its logs/events before debugging higher-level applications.

---

## C. VPC CNI is failing

Check:

```bash
kubectl get pods -n kube-system -l k8s-app=aws-node
```

Then:

```bash
kubectl describe pod -n kube-system <aws-node-pod>
```

Look for IAM/permission errors.

In our incident, the important failure was an EC2 permission denial involving:

```text
ec2:DescribeNetworkInterfaces
```

The fix was to give the VPC CNI its dedicated IAM role through EKS Pod Identity.

---

## D. EKS add-on is `DEGRADED`

Do not immediately assume the add-on itself is the root cause.

Check:

```bash
aws eks describe-addon \
  --cluster-name devboard \
  --addon-name <addon-name> \
  --region us-west-2 \
  --query 'addon.{Status:status,Issues:health.issues}'
```

Then check:

```bash
kubectl get nodes
kubectl get pods -n kube-system -o wide
```

In our case, the add-on symptoms were downstream of unhealthy nodes/CNI.

---

## E. StorageClass does not create volumes

Check the StorageClass:

```bash
kubectl get storageclass
kubectl describe storageclass gp3
```

Expected:

```text
Provisioner:       ebs.csi.aws.com
VolumeBindingMode: WaitForFirstConsumer
```

Then check the EBS CSI components:

```bash
kubectl get pods -n kube-system | grep ebs-csi
```

If the PVC is still pending, inspect it:

```bash
kubectl describe pvc <pvc-name>
```

Then inspect the consuming Pod and events.

---

## F. Terraform Kubernetes resource cannot connect

If Terraform reports a connection similar to:

```text
127.0.0.1
localhost
connection refused
```

check the Kubernetes provider configuration.

The provider needs:

```text
EKS endpoint
Cluster CA
AWS exec authentication
```

Also verify that AWS credentials can identify the current IAM identity:

```bash
aws sts get-caller-identity
```

And verify EKS access:

```bash
aws eks describe-cluster \
  --name devboard \
  --region us-west-2
```

---

# 19. Final Verified State

## Nodes

```text
3 nodes
3 × Ready
```

Conditions verified:

```text
MemoryPressure   False
DiskPressure     False
PIDPressure      False
Ready            True
```

## System Pods

The important system components were verified healthy:

```text
aws-node
coredns
ebs-csi-controller
ebs-csi-node
eks-pod-identity-agent
kube-proxy
metrics-server
```

## EKS Add-ons

```text
vpc-cni                 ACTIVE
kube-proxy              ACTIVE
eks-pod-identity-agent  ACTIVE
aws-ebs-csi-driver      ACTIVE
metrics-server          ACTIVE
coredns                 ACTIVE
```

Health issues:

```text
None
```

## Node Group

```text
Status:        ACTIVE
Health issues: []
```

## StorageClass

```text
Name:                 gp3
Default:              Yes
Provisioner:          ebs.csi.aws.com
Volume type:          gp3
Encrypted:            true
Filesystem:           ext4
ReclaimPolicy:        Delete
VolumeBindingMode:    WaitForFirstConsumer
Expansion:            Enabled
Events:               none
```

---

# 20. Lessons Learned

## 20.1 Troubleshoot from the bottom up

The biggest lesson from this build was dependency order.

Use this sequence:

```text
VPC / networking
       ↓
EKS control plane
       ↓
IAM
       ↓
VPC CNI
       ↓
Worker nodes
       ↓
System add-ons
       ↓
Storage
       ↓
Application
```

If nodes are `NotReady`, do not start by debugging the application.

---

## 20.2 A Terraform resource is not the same as an AWS/Kubernetes object

For example:

```hcl
resource "kubernetes_storage_class_v1" "gp3" {}
```

is Terraform syntax describing a Kubernetes resource.

Inside it:

```text
storage_provisioner
volume_binding_mode
metadata.annotations
```

are Kubernetes concepts exposed through the Terraform provider.

The provider is the bridge:

```text
Terraform
   ↓
Kubernetes Provider
   ↓
Kubernetes API
   ↓
EKS
```

---

## 20.3 IAM failures often appear as Kubernetes failures

Our node problem looked like a Kubernetes health problem:

```text
Node → NotReady
```

But the deeper problem was AWS permission failure:

```text
VPC CNI
   ↓
AWS EC2 API
   ↓
AccessDenied
```

This is why EKS troubleshooting requires checking both sides:

```text
kubectl
+
AWS CLI
```

---

## 20.4 `depends_on` does not mean “wait until healthy”

Terraform dependency means:

```text
Create A before B
```

It does not mean:

```text
Create A
↓
wait until every Kubernetes/AWS component is healthy
↓
then create B
```

Actual service health still needs to be verified separately.

---

## 20.5 Do not memorize undocumented-looking values

When we see:

```text
k8s-app=aws-node
```

find the Kubernetes resource that owns the label.

When we see:

```text
ebs.csi.aws.com
```

identify the CSI driver.

When we see:

```text
storageclass.kubernetes.io/is-default-class=true
```

identify it as a Kubernetes annotation.

When we see:

```text
WaitForFirstConsumer
```

identify it as a Kubernetes StorageClass binding mode.

This makes the configuration understandable instead of turning it into a list of values to memorize.

---

# 21. Project Checkpoint

```text
[✓] VPC
[✓] Public/private subnet design
[✓] NAT / outbound connectivity
[✓] EKS cluster
[✓] EKS API authentication
[✓] Cluster creator admin access
[✓] EKS control-plane logging
[✓] IAM roles
[✓] EKS Pod Identity Agent
[✓] VPC CNI
[✓] VPC CNI Pod Identity
[✓] kube-proxy
[✓] CoreDNS
[✓] EBS CSI
[✓] EBS CSI Pod Identity
[✓] Metrics Server
[✓] Managed node group
[✓] Nodes Ready
[✓] gp3 StorageClass
[✓] gp3 default StorageClass
[✓] Terraform outputs
[✓] Troubleshooting documentation
```

---

# 22. Next Phase

The EKS foundation is healthy.

The next phase can focus on the DevBoard Kubernetes/application layer rather than continuing to troubleshoot the EKS foundation.

The recommended progression is:

```text
EKS foundation          ✓
      ↓
Kubernetes namespaces
      ↓
ConfigMaps / Secrets
      ↓
Deployments
      ↓
Services
      ↓
Persistent workloads
      ↓
Gateway / HTTPRoute
      ↓
External Secrets
      ↓
Application deployment
      ↓
Observability
```

---

## Reference

Terraform Kubernetes provider authentication documentation:

https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#authentication

