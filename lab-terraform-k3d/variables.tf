# ── Cluster ────────────────────────────────────────────────
variable "cluster_name" {
  type        = string
  default     = "voteapp"
  description = "Nome do cluster k3d"
}

variable "agent_count" {
  type        = number
  default     = 2
  description = "Número de nós agents no cluster"
}

variable "k3s_image" {
  type        = string
  default     = "rancher/k3s:v1.29.6-k3s2"
  description = "Imagem k3s usada pelo k3d para evitar incompatibilidades de runtime"
}

variable "create_namespaces" {
  type        = bool
  default     = true
  description = "Cria namespaces Kubernetes quando o contexto estiver presente no kubeconfig"
}

variable "kubeconfig_context" {
  type        = string
  default     = null
  nullable    = true
  description = "Contexto do kubeconfig (ex.: k3d-voteapp). Se null, usa automaticamente k3d-<cluster_name>"
}

# ── Postgres ────────────────────────────────────────────────
variable "postgres_db" {
  type        = string
  default     = "db"
  description = "Nome do banco de dados Postgres"
}

variable "postgres_storage_size" {
  type        = string
  default     = "1Gi"
  description = "Tamanho do PVC do Postgres"
}

# ── Aplicação ───────────────────────────────────────────────
variable "vote_replicas" {
  type        = number
  default     = 2
  description = "Número de réplicas do serviço vote"
}

variable "vote_image" {
  type        = string
  default     = "dockersamples/examplevotingapp_vote"
  description = "Imagem Docker do serviço vote"
}

variable "result_image" {
  type        = string
  default     = "dockersamples/examplevotingapp_result"
  description = "Imagem Docker do serviço result"
}

variable "worker_image" {
  type        = string
  default     = "dockersamples/examplevotingapp_worker"
  description = "Imagem Docker do worker"
}

# ── Monitoramento ───────────────────────────────────────────
variable "grafana_password" {
  type        = string
  default     = "admin123"
  description = "Senha do Grafana (não commitar em produção)"
  sensitive   = true
}

variable "prometheus_chart_version" {
  type        = string
  default     = "55.0.0"
  description = "Versão do chart kube-prometheus-stack"
}