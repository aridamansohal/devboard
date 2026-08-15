# ============================================================
# EKS Control Plane Logging
# ============================================================

# Store EKS control-plane logs in CloudWatch.
# The log group is kept for 7 days to match the Mega Project.
resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = 7

}

