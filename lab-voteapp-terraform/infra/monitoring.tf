resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  version    = var.prometheus_chart_version

  set {
    name  = "grafana.adminPassword"
    value = var.grafana_password
  }

  set {
    name  = "nodeExporter.enabled"
    value = false
  }

  depends_on = [kubernetes_namespace.monitoring]
}
