resource "kubernetes_deployment_v1" "vote" {
  metadata {
    name      = "vote"
    namespace = "voteapp"
    labels = {
      app = "vote"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "vote"
      }
    }

    template {
      metadata {
        labels = {
          app = "vote"
        }
      }

      spec {
        container {
          name  = "vote"
          image = var.vote_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 80
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "300m"
              memory = "128Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.voteapp,
    kubernetes_deployment_v1.redis
  ]
}

resource "kubernetes_service_v1" "vote" {
  metadata {
    name      = "vote"
    namespace = "voteapp"
    labels = {
      app = "vote"
    }
  }

  spec {
    selector = {
      app = "vote"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.vote]
}

resource "kubernetes_deployment_v1" "result" {
  metadata {
    name      = "result"
    namespace = "voteapp"
    labels = {
      app = "result"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "result"
      }
    }

    template {
      metadata {
        labels = {
          app = "result"
        }
      }

      spec {
        container {
          name  = "result"
          image = var.result_image
          image_pull_policy = "IfNotPresent"

          port {
            name           = "http"
            container_port = 80
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.voteapp,
    kubernetes_deployment_v1.db
  ]
}

resource "kubernetes_service_v1" "result" {
  metadata {
    name      = "result"
    namespace = "voteapp"
    labels = {
      app = "result"
    }
  }

  spec {
    selector = {
      app = "result"
    }

    port {
      name        = "http"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.result]
}

resource "kubernetes_deployment_v1" "worker" {
  metadata {
    name      = "worker"
    namespace = "voteapp"
    labels = {
      app = "worker"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "worker"
      }
    }

    template {
      metadata {
        labels = {
          app = "worker"
        }
      }

      spec {
        container {
          name              = "worker"
          image             = var.worker_image
          image_pull_policy = "IfNotPresent"

          env {
            name  = "REDIS_HOST"
            value = "redis"
          }

          env {
            name  = "DB_HOST"
            value = "db"
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace.voteapp,
    kubernetes_deployment_v1.redis,
    kubernetes_deployment_v1.db
  ]
}

resource "kubernetes_manifest" "vote_service_monitor" {
  count = var.create_voteapp_monitoring && var.enable_voteapp_service_monitor_manifests ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "voteapp-vote"
      namespace = "voteapp"
      labels = {
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      namespaceSelector = {
        matchNames = ["voteapp"]
      }
      selector = {
        matchLabels = {
          app = "vote"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_service_v1.vote
  ]
}

resource "kubernetes_manifest" "result_service_monitor" {
  count = var.create_voteapp_monitoring && var.enable_voteapp_service_monitor_manifests ? 1 : 0

  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "voteapp-result"
      namespace = "voteapp"
      labels = {
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      namespaceSelector = {
        matchNames = ["voteapp"]
      }
      selector = {
        matchLabels = {
          app = "result"
        }
      }
      endpoints = [
        {
          port     = "http"
          path     = "/metrics"
          interval = "30s"
        }
      ]
    }
  }

  depends_on = [
    helm_release.kube_prometheus_stack,
    kubernetes_service_v1.result
  ]
}
