data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# ───────────────────────────────────────
# EKS Cluster IAM Role
# ───────────────────────────────────────

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-cluster-role" })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ───────────────────────────────────────
# EKS Node Group IAM Role
# ───────────────────────────────────────

resource "aws_iam_role" "node_group" {
  name = "${var.cluster_name}-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-node-group-role" })
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# ───────────────────────────────────────
# EKS Cluster
# ───────────────────────────────────────

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = var.cluster_endpoint_private_access
    endpoint_public_access  = var.cluster_endpoint_public_access
    security_group_ids      = var.additional_security_group_ids
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]

  tags = merge(var.tags, { Name = var.cluster_name })
}

# ───────────────────────────────────────
# EKS Node Group
# ───────────────────────────────────────

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  capacity_type   = "ON_DEMAND"
  instance_types  = var.node_group_instance_types

  scaling_config {
    desired_size = var.node_group_desired_size
    min_size     = var.node_group_min_size
    max_size     = var.node_group_max_size
  }

  update_config {
    max_unavailable_percentage = 50
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = merge(var.tags, { Name = var.node_group_name })
}

# ───────────────────────────────────────
# OIDC Provider (for IRSA if needed)
# ───────────────────────────────────────

data "tls_certificate" "cluster" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer

  tags = merge(var.tags, { Name = "${var.cluster_name}-oidc" })
}

# ───────────────────────────────────────
# EKS Pod Identity Agent
# ───────────────────────────────────────

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  depends_on = [aws_eks_node_group.this]

  tags = merge(var.tags, { Name = "pod-identity-agent-${var.cluster_name}" })
}

# ───────────────────────────────────────
# Pod Identity - IAM Policy for app
# ───────────────────────────────────────

data "aws_iam_policy_document" "pod_app" {
  dynamic "statement" {
    for_each = var.secrets_manager_arn != "" ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
      ]
      resources = var.secret_name != "" ? ["arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.secret_name}*"] : [var.secrets_manager_arn]
    }
  }

  dynamic "statement" {
    for_each = var.sqs_queue_arn != "" ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      resources = [var.sqs_queue_arn]
    }
  }
}

resource "aws_iam_policy" "pod_app" {
  count       = var.pod_sa_name != "" ? 1 : 0
  name        = "${var.cluster_name}-pod-app-policy"
  description = "Policy for app pods to access Secrets Manager and SQS"
  policy      = data.aws_iam_policy_document.pod_app.json

  tags = merge(var.tags, { Name = "${var.cluster_name}-pod-app-policy" })
}

# ───────────────────────────────────────
# Pod Identity - IAM Role
# ───────────────────────────────────────

resource "aws_iam_role" "pod_app" {
  count = var.pod_sa_name != "" ? 1 : 0
  name  = "${var.cluster_name}-pod-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-pod-app-role" })
}

resource "aws_iam_role_policy_attachment" "pod_app" {
  count      = var.pod_sa_name != "" ? 1 : 0
  role       = aws_iam_role.pod_app[0].name
  policy_arn = aws_iam_policy.pod_app[0].arn
}

# ───────────────────────────────────────
# Pod Identity Association
# ───────────────────────────────────────

resource "aws_eks_pod_identity_association" "app" {
  count           = var.pod_sa_name != "" ? 1 : 0
  cluster_name    = aws_eks_cluster.this.name
  namespace       = var.pod_sa_namespace
  service_account = var.pod_sa_name
  role_arn        = aws_iam_role.pod_app[0].arn

  depends_on = [aws_eks_addon.pod_identity_agent]

  tags = merge(var.tags, { Name = "${var.pod_sa_name}-pia-${var.cluster_name}" })
}
