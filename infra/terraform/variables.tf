# variables.tf
# Déclaration des variables d'entrée pour rendre l'infrastructure configurable

variable "project_name" {
  description = "Nom du projet (utilisé comme préfixe pour les ressources)"
  type        = string
  default     = "devops-local-lab"
}

variable "app_image" {
  description = "Image Docker de l'application Flask"
  type        = string
  default     = "devops-local-app"
}

variable "app_version" {
  description = "Version de l'application"
  type        = string
  default     = "latest"
}