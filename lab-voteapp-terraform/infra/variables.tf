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
  description = "Cria namespaces Kubernetes para os recursos da aplicacao"
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

variable "postgres_use_pvc" {
  type        = bool
  default     = true
  description = "Se true, usa PVC para persistencia do Postgres; se false, usa armazenamento efemero"
}

variable "create_db_bootstrap_job" {
  type        = bool
  default     = false
  description = "Cria job Kubernetes para inicializar a tabela votes no Postgres"
}

variable "postgres_storage_class" {
  type        = string
  default     = null
  nullable    = true
  description = "StorageClass usada pelo PVC do Postgres (null = classe padrao do cluster)"
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

variable "create_voteapp_monitoring" {
  type        = bool
  default     = true
  description = "Se true, cria ServiceMonitors para os serviços vote e result"
}

variable "enable_voteapp_service_monitor_manifests" {
  type        = bool
  default     = false
  description = "Habilita criacao dos ServiceMonitors em segunda etapa, apos cluster e stack de monitoramento estarem ativos"
}

variable "vote_image" {
  type        = string
  default     = "dockersamples/examplevotingapp_vote"
  description = "Imagem do serviço vote"
}

variable "result_image" {
  type        = string
  default     = "dockersamples/examplevotingapp_result"
  description = "Imagem do serviço result"
}

variable "worker_image" {
  type        = string
  default     = "dockersamples/examplevotingapp_worker"
  description = "Imagem do serviço worker"
}