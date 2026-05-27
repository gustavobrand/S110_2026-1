output "container_id" {
  value       = docker_container.nginx.id
  description = "ID do container criado"
}

output "url" {
  value       = "http://localhost:${var.external_port}"
  description = "URL para acessar o Nginx"
}