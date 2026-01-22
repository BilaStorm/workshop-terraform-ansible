terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.0"
    }
  }
}

provider "docker" {
    host = "npipe:////./pipe/docker_engine"

}

# Création du réseau (demandé dans les critères)
resource "docker_network" "private_network" {
  name = "devops-lab-network"
}

# Référence à l'image qu'on a construite manuellement à l'étape 1
resource "docker_image" "flask_app" {
  name         = "devops-local-lab-flask:latest"
  keep_locally = true
}

# Création du conteneur (demandé dans les critères)
resource "docker_container" "app" {
  image = docker_image.flask_app.image_id
  name  = "devops-lab-flask-container"
  
  ports {
    internal = 5000 # Port standard de Flask
    external = 8080 # Port demandé pour le curl
  }

  networks_advanced {
    name = docker_network.private_network.name
  }
}