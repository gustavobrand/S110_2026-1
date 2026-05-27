variable "container_name" {
  type        = string
  default     = "nginx-tf2"
  description = "Nome do container Docker"
}

variable "external_port" {
  type        = number
  default     = 8080
  description = "Porta exposta no host"
}