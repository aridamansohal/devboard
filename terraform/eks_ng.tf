resource "aws_iam_role" "this" {
  name = "eks-node-group-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_node_policies" {
  for_each   = toset(local.node_policy_arns)
  policy_arn = each.value
  role       = aws_iam_role.this.name
}




resource "aws_launch_template" "eks_node" {
  name = "${var.cluster_name}-node-lt"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp3"
    }
  }

  ebs_optimized = true

  tags = {
    Name = "${var.cluster_name}-node"
  }
}



resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.this.arn
  subnet_ids      = module.vpc.private_subnets

  ami_type       = var.ami_type
  instance_types = var.node_instance_type



  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    name    = aws_launch_template.eks_node.name
    version = aws_launch_template.eks_node.latest_version

  }
  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
  depends_on = [
    aws_iam_role_policy_attachment.eks_node_policies,
    # These add-ons must be ready before worker nodes are created.

  ]
  tags = {
    NodeGroup = "default"
  }
}


