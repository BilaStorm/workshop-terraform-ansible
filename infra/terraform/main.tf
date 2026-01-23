# --- 1. Variables Locales & Logique ---
locals {
  # Si tu as un fichier variables.tf, garde var.project_name.
  project = var.project_name

  # Gestion intelligente du workspace (dev ou prod)
  env = terraform.workspace == "default" ? "dev" : terraform.workspace

  # Nom complet de l'image de ton application
  app_image = "${local.project}-flask:latest"
}

# --- 2. Réseau Docker ---
resource "docker_network" "app_net" {
  name = "${local.project}-${local.env}-net"
}

# --- 3. Construction de l'image Flask ---
# Terraform construit l'image pour qu'elle soit prête pour Ansible
resource "docker_image" "flask_image_build" {
  name = local.app_image

  build {
    context  = "${path.module}/../../app"
    tag      = [local.app_image]
    no_cache = true
  }
}

# --- 4. Conteneur Flask (Application) ---
# ⚠️ MIS EN COMMENTAIRE : C'est maintenant ANSIBLE qui lance ce conteneur.
# Cela évite le conflit de port 5000 lors du "make deploy".
# resource "docker_container" "flask_app" {
#   name = "${local.project}-${local.env}-app"
#   image = docker_image.flask_image_build.image_id
#   networks_advanced {
#     name = docker_network.app_net.name
#   }
#   env = [
#     "APP_ENV=${local.env}",
#     "PORT=5000"
#   ]
#   ports {
#     internal = 5000
#     external = 5000
#   }
#   restart = "unless-stopped"
# }

# --- 5. Image Nginx (Docker) ---
resource "docker_image" "nginx" {
  name = "nginx:1.27-alpine"
}

# --- 6. Fichier de Configuration Nginx (Pour Docker uniquement) ---
# ⚠️ MIS EN COMMENTAIRE car il dépend du conteneur flask_app ci-dessus.
# Ansible génère sa propre configuration via son template Jinja2.
# resource "local_file" "nginx_conf" {
#   filename = "${path.module}/generated/nginx.conf"
#   content          = <<-EOT
#     server {
#       listen 80;
#       server_name localhost;
#       location / {
#         proxy_set_header Host $host;
#         proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#         proxy_pass http://${docker_container.flask_app.name}:5000;
#       }
#       location /health {
#         proxy_pass http://${docker_container.flask_app.name}:5000/health;
#         access_log off;
#       }
#     }
#   EOT
#   file_permission = "0644"
# }

# --- 7. Conteneur Nginx (Docker) ---
# ⚠️ MIS EN COMMENTAIRE : Ansible gère Nginx.
# resource "docker_container" "nginx" {
#   name  = "${local.project}-${local.env}-nginx"
#   image = docker_image.nginx.name
#   networks_advanced {
#     name = docker_network.app_net.name
#   }
#   ports {
#     internal = 80
#     external = 8080 
#   }
#   volumes {
#     host_path      = abspath(local_file.nginx_conf.filename)
#     container_path = "/etc/nginx/conf.d/default.conf"
#     read_only      = true
#   }
#   restart    = "unless-stopped"
#   depends_on = [local_file.nginx_conf, docker_container.flask_app]
# }

# --- 8. Génération automatique de l'inventory Ansible (SANS SSH) ---
resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"

  content = <<-EOT
    # Inventory Ansible généré automatiquement par Terraform
    # Mode : LOCAL (Pas de SSH)

    [vm]
    localhost ansible_connection=local
  EOT

  file_permission = "0644"
}