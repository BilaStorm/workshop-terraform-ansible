# --- 1. Variables Locales & Logique ---
locals {
  # On récupère le nom de base depuis variables.tf
  project = var.project_name
  
  # Gestion intelligente du workspace (dev ou prod)
  env = terraform.workspace == "default" ? "dev" : terraform.workspace
  
  # Nom complet de l'image de ton application
  app_image = "${local.project}-flask:latest"

  # Port SSH pour la VM Ansible (ajouté ici pour être accessible partout)
  ssh_port = 2223
}

# --- 2. Réseau Docker ---
resource "docker_network" "app_net" {
  name = "${local.project}-${local.env}-net"
}

# --- 3. Conteneur Flask (Application) ---
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
    # Port 5000 pour DEV, Port 5001 pour PROD
    external = local.env == "prod" ? 5001 : 5000
  }

  restart = "unless-stopped"
}

# --- 4. Image Nginx (Reverse Proxy) ---
resource "docker_image" "nginx" {
  name = "nginx:1.27-alpine"
}

# --- 5. Fichier de Configuration Nginx ---
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
    # Port 80 pour PROD, 8080 pour DEV
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

# --- 7. Génération automatique de l'inventory Ansible ---
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  
  content = <<-EOT
    # Inventory Ansible généré automatiquement par Terraform
    # Environnement : ${local.env}

    [vm]
    127.0.0.1 ansible_port=${local.ssh_port} ansible_user=ansible ansible_password=ansible ansible_connection=ssh

    [vm:vars]
    ansible_python_interpreter=/usr/bin/python3
    ansible_become=yes
    ansible_become_method=sudo
    ansible_become_pass=ansible
  EOT
  
  file_permission = "0644"
}