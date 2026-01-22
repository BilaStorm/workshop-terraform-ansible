# variables.tf

variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "devops-local-lab"
}

variable "app_port" {
  description = "Port interne de l'application Flask"
  type        = number
  default     = 5000
}

variable "nginx_version" {
  description = "Version de l'image Docker Nginx"
  type        = string
  default     = "1.27-alpine"
}