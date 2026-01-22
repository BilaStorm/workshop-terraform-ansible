terraform {
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

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# --- 1. Variables Locales & Workspace ---
locals {
  project = "devops-local-lab"
  
  # Gestion intelligente du workspace :
  # Si on est dans "default", on force "dev". Sinon, on prend le nom du workspace (dev, prod).
  env = terraform.workspace == "default" ? "dev" : terraform.workspace
  
  # Nom de l'image de ton app (doit exister localement ou sur un registry)
  app_image = "${local.project}-flask:latest"
}

# --- 2. Réseau ---
# J'ai remis le nom "app_net" pour correspondre à ton appel plus bas
resource "docker_network" "app_net" {
  name = "${local.project}-${local.env}-net"
}

# --- 3. Conteneur Flask (App) ---
resource "docker_container" "flask_app" {
  name  = "${local.project}-${local.env}-app"
  
  # CORRECTION : On utilise la variable locale, pas une ressource "docker_image" qui n'existe pas
  image = local.app_image

  networks_advanced {
    # CORRECTION : On référence bien "app_net" défini plus haut
    name = docker_network.app_net.name
  }

  env = [
    "APP_ENV=${local.env}",
    "PORT=5000"
  ]

  ports {
    internal = 5000
    external = 5000
  }

  restart = "unless-stopped"
}

# --- 4. Image Nginx ---
resource "docker_image" "nginx" {
  name = "nginx:1.27-alpine"
}

# --- 5. Config Nginx ---
resource "local_file" "nginx_conf" {
  filename = "${path.module}/generated/nginx.conf"

  content = <<-EOT
    server {
      listen 80;
      location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_pass http://${docker_container.flask_app.name}:5000;
      }
      location /health {
        proxy_pass http://${docker_container.flask_app.name}:5000/health;
        access_log off;
      }
    }
  EOT

  file_permission = "0644"
}

# --- 6. Conteneur Nginx ---
resource "docker_container" "nginx" {
  name  = "${local.project}-${local.env}-nginx"
  image = docker_image.nginx.name

  networks_advanced {
    name = docker_network.app_net.name
  }

  ports {
    internal = 80
    # Petite astuce : si env=prod port 80, si env=dev port 8080
    external = local.env == "prod" ? 80 : 8080
  }

  volumes {
    host_path      = abspath(local_file.nginx_conf.filename)
    container_path = "/etc/nginx/conf.d/default.conf"
    read_only      = true
  }

  restart    = "unless-stopped"
  depends_on = [local_file.nginx_conf, docker_container.flask_app]
}