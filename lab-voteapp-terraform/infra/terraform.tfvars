# sobrescrever defaults aqui — não commitar se tiver senhas
cluster_name = "voteapp"
# agent_count      = 2
k3s_image                = "rancher/k3s:v1.29.6-k3s2"
vote_replicas            = 2
grafana_password         = "admin123"
prometheus_chart_version = "86.1.1"
postgres_use_pvc         = false
create_db_bootstrap_job  = false