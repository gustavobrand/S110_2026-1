resource "kubernetes_deployment_v1" "redis" {
  metadata {
    name      = "redis"
    namespace = "voteapp"
    labels = {
      app = "redis"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          name  = "redis"
          image = "redis:alpine"

          port {
            container_port = 6379
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.voteapp]
}

resource "kubernetes_service_v1" "redis" {
  metadata {
    name      = "redis"
    namespace = "voteapp"
  }

  spec {
    selector = {
      app = "redis"
    }

    port {
      port        = 6379
      target_port = 6379
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.voteapp]
}
