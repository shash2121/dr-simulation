resource "aws_iam_policy" "AWSLoadBalancerControllerIAMPolicy" {
  name        = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for granting permissions to AWS Load Balancer Controller"

  policy = file("${path.module}/../aws-policies/aws-load-balancer-controller-policy.json")

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  })
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${var.cluster_name}-aws-load-balancer-controller-role"

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

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-aws-load-balancer-controller-role"
  })
}

# Attach AWS Load Balancer Controller IAM Policy
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.AWSLoadBalancerControllerIAMPolicy.arn
}

resource "aws_eks_pod_identity_association" "aws_lbc_sa" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_load_balancer_controller.arn

  depends_on = [aws_eks_addon.pod_identity_agent]

  tags = merge(var.tags, { Name = "aws-lbc-pia-${var.cluster_name}" })
}

# AWS Load Balancer Controller Helm Chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set = [
    {
      name  = "clusterName"
      value = aws_eks_cluster.this.name
    },
    {
      name  = "region"
      value = var.aws_region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
  ]

  depends_on = [
    aws_iam_role.aws_load_balancer_controller,
    aws_eks_pod_identity_association.aws_lbc_sa
  ]

  lifecycle {
    ignore_changes = [
      chart,
      version,
    ]
  }
}
