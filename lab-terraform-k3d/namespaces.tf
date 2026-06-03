resource "null_resource" "namespace_voteapp" {
  triggers = {
    cluster_name = var.cluster_name
    namespace    = "voteapp"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      kubectl --context "k3d-${var.cluster_name}" get namespace voteapp >/dev/null 2>&1 || kubectl --context "k3d-${var.cluster_name}" create namespace voteapp
      kubectl --context "k3d-${var.cluster_name}" label namespace voteapp app=vote-application --overwrite
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = "kubectl --context \"k3d-${self.triggers.cluster_name}\" delete namespace voteapp --ignore-not-found=true"
  }

  depends_on = [null_resource.k3d_cluster]
}

resource "null_resource" "namespace_monitoring" {
  triggers = {
    cluster_name = var.cluster_name
    namespace    = "monitoring"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = "kubectl --context \"k3d-${var.cluster_name}\" get namespace monitoring >/dev/null 2>&1 || kubectl --context \"k3d-${var.cluster_name}\" create namespace monitoring"
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = "kubectl --context \"k3d-${self.triggers.cluster_name}\" delete namespace monitoring --ignore-not-found=true"
  }

  depends_on = [null_resource.k3d_cluster]
}