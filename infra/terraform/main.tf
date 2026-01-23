terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "docker" {}

# --- 1. Variables Locales & Logique ---
locals {
  # Si tu n'as pas de variables.tf, remplace var.project_name par "devops-local-lab"
  project = var.project_name 
  
  # Gestion intelligente du workspace (dev ou prod)
  env = terraform.workspace == "default" ? "dev" : terraform.workspace
  
  # Nom complet de l'image de ton application
  app_image = "${local.project}-flask:latest"

  # Port SSH pour la VM Ansible
  ssh_port = 2223
}

# --- 2. Réseau Docker ---
resource "docker_network" "app_net" {
  name = "${local.project}-${local.env}-net"
}

# --- 3. Construction de l'image Flask (AJOUT CRUCIAL) ---
# C'est ce bloc qui empêche l'erreur "pull access denied"
resource "docker_image" "flask_image_build" {
  name = local.app_image

  build {
    context = "${path.module}/../../app"
    tag     = [local.app_image]
    no_cache = true
  }
}

# --- 4. Conteneur Flask (Application) ---
resource "docker_container" "flask_app" {
  name  = "${local.project}-${local.env}-app"
  
  # MODIFICATION : On utilise l'ID de l'image construite juste au-dessus
  image = docker_image.flask_image_build.image_id

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

# --- 5. Image Nginx (Reverse Proxy) ---
resource "docker_image" "nginx" {
  name = "nginx:1.27-alpine"
}

# --- 6. Fichier de Configuration Nginx ---
resource "local_file" "nginx_conf" {
  filename = "${path.module}/generated/nginx.conf"

  content = <<-EOT
    server {
      listen 80;
      server_name localhost;

      location / {
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        # Ici on utilise le nom DNS interne du conteneur Docker
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

# --- 7. Conteneur Nginx ---
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

# --- 8. Génération automatique de l'inventory Ansible ---
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