# ------------------------------------ Installing CSI secrets store and AWS secrets provider ------------------------------------

# 1. Secrets Store CSI Driver
resource "helm_release" "csi_secrets_store" {
  depends_on = [aws_eks_node_group.this]
  name       = "csi-secrets-store"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"

  set = [
    {
      name  = "syncSecret.enabled"
      value = "true"
    },
    {
      name  = "enableSecretRotation"
      value = "true"
    },
    {
      name  = "tokenRequests[0].audience"
      value = "pods.eks.amazonaws.com"
    },
  ]
}

# 2. AWS Secrets Manager Provider
resource "helm_release" "secrets_provider_aws" {
  name       = "secrets-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"

  set = [
    {
      name  = "secrets-store-csi-driver.install"
      value = "false"
    },
  ]

  depends_on = [helm_release.csi_secrets_store]
}
