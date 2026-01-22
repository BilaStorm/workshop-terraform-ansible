output "container_nginx_name" {
  description = "Nom du conteneur Nginx"
  value       = docker_container.nginx.name
}

output "nginx_url" {
  description = "URL d'accès à l'application via Nginx"
  # On récupère le port externe directement depuis la configuration du conteneur
  value       = "http://localhost:${docker_container.nginx.ports[0].external}"
}

output "flask_app_url" {
  description = "URL d'accès direct à Flask (sans passer par Nginx)"
  # On récupère le port externe du conteneur Flask (5000 ou 5001)
  value       = "http://localhost:${docker_container.flask_app.ports[0].external}"
}

output "docker_network_name" {
  description = "Nom du réseau Docker utilisé"
  # Correction : on pointe vers 'app_net' comme défini dans main.tf
  value       = docker_network.app_net.name
}