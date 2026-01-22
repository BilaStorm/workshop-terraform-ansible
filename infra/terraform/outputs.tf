# outputs.tf
# Expose les informations importantes de l'infrastructure

output "environment" {
  description = "Environnement actif (workspace)"
  value       = local.env
}

output "nginx_port" {
  description = "Port externe du serveur Nginx"
  value       = local.nginx_port
}

output "docker_network_name" {
  description = "Nom du réseau Docker créé"
  value       = docker_network.devops_net.name
}

output "nginx_container_name" {
  description = "Nom du conteneur Nginx"
  value       = docker_container.nginx.name
}