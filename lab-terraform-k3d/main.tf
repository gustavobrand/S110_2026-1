terraform {
  required_version = ">= 1.3"
  required_providers {
    k3d = {
      source  = "pvotal-tech/k3d"
      version = "~> 0.0.7"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# ── Cluster k3d ────────────────────────────────────────────
resource "k3d_cluster" "voteapp" {
  name    = var.cluster_name
  servers = 1
  agents  = var.agent_count
  image   = var.k3s_image

  k3s {
    extra_args {
      arg          = "--disable=traefik"
      node_filters = ["server:*"]
    }

    extra_args {
      arg          = "--disable=servicelb"
      node_filters = ["server:*"]
    }
  }

  kubeconfig {
    update_default_kubeconfig = true
    switch_current_context    = true
  }

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

provider "kubernetes" {
  host                   = k3d_cluster.voteapp.credentials[0].host
  client_certificate     = k3d_cluster.voteapp.credentials[0].client_certificate
  client_key             = k3d_cluster.voteapp.credentials[0].client_key
  cluster_ca_certificate = k3d_cluster.voteapp.credentials[0].cluster_ca_certificate
}
