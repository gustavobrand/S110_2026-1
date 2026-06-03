terraform {
  required_version = ">= 1.3"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# ── Cluster k3d ────────────────────────────────────────────
resource "null_resource" "k3d_cluster" {
  triggers = {
    cluster_name = var.cluster_name
    agent_count  = tostring(var.agent_count)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-lc"]
    command     = <<-EOT
      set -euo pipefail
      retries=3

      for attempt in $(seq 1 "$retries"); do
        k3d cluster delete "${var.cluster_name}" >/dev/null 2>&1 || true

        if k3d cluster create "${var.cluster_name}" --servers 1 --agents "${var.agent_count}" -p "80:80@loadbalancer" -p "443:443@loadbalancer" --wait --timeout 180s; then
          k3d kubeconfig merge "${var.cluster_name}" --kubeconfig-switch-context >/dev/null
          kubectl wait --for=condition=Ready nodes --all --timeout=120s
          exit 0
        fi

        echo "k3d create failed on attempt $${attempt}/$${retries}" >&2
        if [[ "$attempt" -lt "$retries" ]]; then
          sleep 10
        fi
      done

      echo "k3d cluster failed to become ready after $${retries} attempts" >&2
      exit 1
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-lc"]
    command     = "k3d cluster delete \"${self.triggers.cluster_name}\" >/dev/null 2>&1 || true"
  }
}
