terraform {
  required_version = ">= 1.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
# Calcul de variables locales selon l'environnement (workspace)
locals {
  # Récupère le workspace actif (dev, prod, ou default)
  env = terraform.workspace

  # Définit les ports par environnement
  ports = {
    default = 8080
    dev     = 8080
    prod    = 80
  }

  # Sélectionne le port correspondant à l'environnement actif
  nginx_port = local.ports[local.env]

  # Génère un suffixe pour les noms de ressources
  env_suffix = local.env == "default" ? "" : "-${local.env}"
}