terraform {
  required_version = ">= 1.3"
  required_providers {
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "~> 0.0.5"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

# ── Cluster k3d ────────────────────────────────────────────
resource "k3d_cluster" "voteapp" {
  name    = var.cluster_name
  servers = 1
  agents  = var.agent_count

  port {
    host_port      = 80
    container_port = 80
    node_filters   = ["loadbalancer"]
  }

  port {
    host_port      = 443
    container_port = 443
    node_filters   = ["loadbalancer"]
  }
}

# ── Provider Kubernetes ─────────────────────────────────────
# lê o kubeconfig gerado automaticamente pelo k3d
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "k3d-${var.cluster_name}"
  depends_on     = [k3d_cluster.voteapp]
}

# ── Provider Helm ───────────────────────────────────────────
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "k3d-${var.cluster_name}"
  }
  depends_on = [k3d_cluster.voteapp]
}