# ============================================================
# EKS Storage
# ============================================================

# Create gp3 as the default Kubernetes StorageClass.
# This allows PVCs to automatically use encrypted gp3 EBS volumes.

resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"

    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }

  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"

  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }
  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.node_group,
    aws_eks_addon.this["aws-ebs-csi-driver"]
  ]

}