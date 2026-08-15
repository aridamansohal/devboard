resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  wait    = true
  timeout = 900

  values = [
    file("${path.module}/argocd_values.yml")
  ]

  depends_on = [aws_eks_cluster.this]
}
