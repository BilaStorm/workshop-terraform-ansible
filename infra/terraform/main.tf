# --- 1. Variables Locales & Logique ---
locals {
  project = var.project_name
  
  # Récupère le nom du workspace (dev ou prod)
  # Si on est dans "default", on bascule sur "dev"
  env = terraform.workspace == "default" ? "dev" : terraform.workspace
  
  app_image = "${local.project}-flask:latest"
  ssh_port  = 2223

  # --- CONFIGURATION DES PORTS NGINX ---
  # Ici on définit quel workspace écoute sur quel port externe
  nginx_ports = {
    "dev"  = 8080
    "prod" = 80   # C'est ici qu'on force le port 80 pour la prod
  }

  # --- CONFIGURATION DES PORTS FLASK ---
  # On décale les ports de l'app pour éviter les conflits
  flask_ports = {
    "dev"  = 5000
    "prod" = 5001
  }
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
    # On regarde dans la liste flask_ports. Si pas trouvé, par défaut 5000.
    external = lookup(local.flask_ports, local.env, 5000)
  }

  restart = "unless-stopped"
}

# --- 4. Image Nginx (Reverse Proxy) ---
resource "docker_image" "nginx" {
  name         = "nginx:1.27-alpine"
  keep_locally = true
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
    # ICI C'EST LA MAGIE :
    # Si env = "prod", ça prend 80.
    # Si env = "dev", ça prend 8080.
    external = lookup(local.nginx_ports, local.env, 8080)
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