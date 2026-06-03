resource "kubernetes_namespace" "voteapp" {
  count = var.create_namespaces ? 1 : 0

  metadata {
    name = "voteapp"
    labels = {
      app = "vote-application"
    }
  }

  depends_on = [k3d_cluster.voteapp]
}

resource "kubernetes_namespace" "monitoring" {
  count = var.create_namespaces ? 1 : 0

  metadata {
    name = "monitoring"
  }

  depends_on = [k3d_cluster.voteapp]
}