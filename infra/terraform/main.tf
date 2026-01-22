# Variables locales (constantes calculées)
locals {
  project   = "devops-local-lab"
  env       = "dev"
  app_image = "${local.project}-flask:latest"
}

# 1. Réseau Docker isolé
resource "docker_network" "app_net" {
  name = "${local.project}-${local.env}-net"
}

# 2. Conteneur Flask (Application)
resource "docker_container" "flask_app" {
  name  = "${local.project}-${local.env}-app"
  image = local.app_image

  networks_advanced {
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

# 3. Image Nginx (on pull l'image officielle)
resource "docker_image" "nginx" {
  name = "nginx:1.27-alpine"
}

# 4. Fichier de configuration Nginx (généré dynamiquement)
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

# 5. Conteneur Nginx (Reverse Proxy)
resource "docker_container" "nginx" {
  name  = "${local.project}-${local.env}-nginx"
  image = docker_image.nginx.name

  networks_advanced {
    name = docker_network.app_net.name
  }

  ports {
    internal = 80
    external = 8080
  }

  volumes {
    host_path      = abspath("${path.module}/generated/nginx.conf")
    container_path = "/etc/nginx/conf.d/default.conf"
    read_only      = true
  }

  restart    = "unless-stopped"
  depends_on = [local_file.nginx_conf, docker_container.flask_app]
}