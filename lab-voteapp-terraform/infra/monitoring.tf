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

resource "helm_release" "loki_stack" {
  count = var.create_loki_stack ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  namespace  = "monitoring"
  version    = var.loki_stack_chart_version

  # Lab setup: keep Loki ephemeral and disable bundled Grafana/Prometheus.
  set {
    name  = "loki.persistence.enabled"
    value = false
  }

  set {
    name  = "promtail.enabled"
    value = true
  }

  set {
    name  = "grafana.enabled"
    value = false
  }

  set {
    name  = "prometheus.enabled"
    value = false
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    helm_release.kube_prometheus_stack
  ]
}

resource "kubernetes_deployment_v1" "jaeger" {
  count = var.create_jaeger ? 1 : 0

  metadata {
    name      = "jaeger"
    namespace = "monitoring"
    labels = {
      app = "jaeger"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "jaeger"
      }
    }

    template {
      metadata {
        labels = {
          app = "jaeger"
        }
      }

      spec {
        container {
          name  = "jaeger"
          image = var.jaeger_image

          env {
            name  = "COLLECTOR_OTLP_ENABLED"
            value = "true"
          }

          port {
            name           = "query-ui"
            container_port = 16686
          }

          port {
            name           = "otlp-grpc"
            container_port = 4317
          }

          port {
            name           = "otlp-http"
            container_port = 4318
          }

          port {
            name           = "collector"
            container_port = 14268
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}

resource "kubernetes_service_v1" "jaeger_query" {
  count = var.create_jaeger ? 1 : 0

  metadata {
    name      = "jaeger-query"
    namespace = "monitoring"
    labels = {
      app = "jaeger"
    }
  }

  spec {
    selector = {
      app = "jaeger"
    }

    port {
      name        = "http-query"
      port        = 16686
      target_port = 16686
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.jaeger]
}

resource "kubernetes_service_v1" "jaeger_collector" {
  count = var.create_jaeger ? 1 : 0

  metadata {
    name      = "jaeger-collector"
    namespace = "monitoring"
    labels = {
      app = "jaeger"
    }
  }

  spec {
    selector = {
      app = "jaeger"
    }

    port {
      name        = "otlp-grpc"
      port        = 4317
      target_port = 4317
    }

    port {
      name        = "otlp-http"
      port        = 4318
      target_port = 4318
    }

    port {
      name        = "collector"
      port        = 14268
      target_port = 14268
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.jaeger]
}
