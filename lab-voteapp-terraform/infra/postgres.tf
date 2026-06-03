resource "kubernetes_secret_v1" "postgres" {
  metadata {
    name      = "postgres-secret"
    namespace = "voteapp"
  }

  type = "Opaque"

  data = {
    POSTGRES_DB               = var.postgres_db
    POSTGRES_HOST_AUTH_METHOD = "trust"
  }

  depends_on = [kubernetes_namespace.voteapp]
}

resource "kubernetes_persistent_volume_claim_v1" "postgres" {
  count = var.postgres_use_pvc ? 1 : 0

  metadata {
    name      = "postgres-pvc"
    namespace = "voteapp"
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = var.postgres_storage_class

    resources {
      requests = {
        storage = var.postgres_storage_size
      }
    }
  }

  depends_on = [kubernetes_namespace.voteapp]
}

resource "kubernetes_deployment_v1" "db" {
  metadata {
    name      = "db"
    namespace = "voteapp"
    labels = {
      app = "db"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "db"
      }
    }

    template {
      metadata {
        labels = {
          app = "db"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:9.4"

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.postgres.metadata[0].name
            }
          }

          port {
            container_port = 5432
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }

        volume {
          name = "postgres-storage"

          dynamic "persistent_volume_claim" {
            for_each = var.postgres_use_pvc ? [1] : []
            content {
              claim_name = kubernetes_persistent_volume_claim_v1.postgres[0].metadata[0].name
            }
          }

          dynamic "empty_dir" {
            for_each = var.postgres_use_pvc ? [] : [1]
            content {}
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.voteapp]
}

resource "kubernetes_service_v1" "db" {
  metadata {
    name      = "db"
    namespace = "voteapp"
  }

  spec {
    selector = {
      app = "db"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_namespace.voteapp]
}

resource "kubernetes_job_v1" "db_bootstrap" {
  count = var.create_db_bootstrap_job ? 1 : 0

  metadata {
    name      = "db-bootstrap"
    namespace = "voteapp"
  }

  spec {
    backoff_limit              = 6
    ttl_seconds_after_finished = 300

    template {
      metadata {
        labels = {
          app = "db-bootstrap"
        }
      }

      spec {
        restart_policy = "OnFailure"

        container {
          name  = "bootstrap"
          image = "postgres:15-alpine"

          command = [
            "sh",
            "-c",
            "until pg_isready -h db -U postgres -d postgres; do sleep 2; done; psql -h db -U postgres -d postgres -c \"CREATE TABLE IF NOT EXISTS votes (id VARCHAR(255) NOT NULL UNIQUE, vote VARCHAR(255) NOT NULL);\""
          ]
        }
      }
    }
  }

  depends_on = [
    kubernetes_deployment_v1.db,
    kubernetes_service_v1.db
  ]
}
