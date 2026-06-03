resource "kubernetes_namespace" "voteapp" {
  metadata {
    name = "voteapp"
    labels = {
      app = "vote-application"
    }
  }
  depends_on = [k3d_cluster.voteapp]
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [k3d_cluster.voteapp]
}