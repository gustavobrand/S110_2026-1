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

locals {
  kubeconfig_path              = pathexpand("~/.kube/config")
  effective_kubeconfig_context = coalesce(var.kubeconfig_context, "k3d-${var.cluster_name}")
  kubeconfig_exists            = fileexists(local.kubeconfig_path)
  kubeconfig_context_names = local.kubeconfig_exists ? [
    for c in coalesce(try(yamldecode(file(local.kubeconfig_path)).contexts, []), []) : c.name
  ] : []
  kubeconfig_context_exists = contains(local.kubeconfig_context_names, local.effective_kubeconfig_context)
}

provider "kubernetes" {
  config_path    = local.kubeconfig_path
  config_context = local.kubeconfig_context_exists ? local.effective_kubeconfig_context : null
}
