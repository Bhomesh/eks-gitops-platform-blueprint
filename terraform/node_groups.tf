# IAM Role for Managed Node Groups
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

# Custom Launch Template with IMDSv2 and Encrypted Storage
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-lt-"

  # CIS AWS Benchmark: Enforce IMDSv2
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 80
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.tags,
      {
        Name = "${var.cluster_name}-worker"
      }
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 1. System Node Group (On-Demand for ArgoCD, Istio, CoreDNS, Monitoring)
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "system-on-demand"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type  = "ON_DEMAND"
  instance_types = ["m6i.xlarge", "m5.xlarge"]

  scaling_config {
    desired_size = var.system_node_desired_size
    max_size     = var.system_node_max_size
    min_size     = var.system_node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  labels = {
    "role" = "system"
  }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(
    var.tags,
    {
      "k8s.io/cluster-autoscaler/node-template/label/role" = "system"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}

# 2. General Workload Node Group (Spot Instances for business applications)
resource "aws_eks_node_group" "workloads" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "workloads-spot"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = aws_subnet.private[*].id

  capacity_type  = "SPOT"
  instance_types = ["c6i.xlarge", "c5.xlarge", "m6i.xlarge"]

  scaling_config {
    desired_size = var.workload_node_desired_size
    max_size     = var.workload_node_max_size
    min_size     = var.workload_node_min_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = "$Latest"
  }

  labels = {
    "role" = "workload"
  }

  tags = merge(
    var.tags,
    {
      "k8s.io/cluster-autoscaler/node-template/label/role" = "workload"
    }
  )

  depends_on = [
    aws_iam_role_policy_attachment.node_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_AmazonEC2ContainerRegistryReadOnly,
  ]
}
