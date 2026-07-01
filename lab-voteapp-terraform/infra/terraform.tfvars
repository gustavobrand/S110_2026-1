# sobrescrever defaults aqui — não commitar se tiver senhas
cluster_name = "voteapp"
# agent_count      = 2
k3s_image                = "rancher/k3s:v1.29.6-k3s2"
grafana_password         = "admin123"
prometheus_chart_version = "86.1.1"
postgres_use_pvc         = false
create_db_bootstrap_job  = false
vote_image               = "app-vote:latest"
result_image             = "app-result:latest"
worker_image             = "app-worker:latest"
# Segunda etapa: habilite como true apos cluster + kube-prometheus-stack estarem criados.
enable_voteapp_service_monitor_manifests = false