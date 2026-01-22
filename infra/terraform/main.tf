# 1. Le Réseau (Network)
resource "docker_network" "private_network" {
  name = "devops-local-lab-dev-net" # Updated name per instructions
}

# 2. Application Python (Image + Container)
resource "docker_image" "flask_app" {
  name         = "devops-local-lab-flask:latest"
  keep_locally = true
}

resource "docker_container" "app" {
  image = docker_image.flask_app.image_id
  name  = "devops-lab-flask-container"
  
  ports {
    internal = 5000
    external = 8080 # This satisfies the curl localhost:8080 requirement
  }

  networks_advanced {
    name = docker_network.private_network.name
  }
}

# 3. Serveur Web Nginx (Image + Container)
# Added per instructions: "Un conteneur pour le serveur web (Nginx)"
resource "docker_image" "nginx" {
  name         = "nginx:latest"
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "devops-lab-nginx-container"

  ports {
    internal = 80
    external = 8000 # Using 8000 to avoid conflict with Python on 8080
  }

  networks_advanced {
    name = docker_network.private_network.name
  }
}