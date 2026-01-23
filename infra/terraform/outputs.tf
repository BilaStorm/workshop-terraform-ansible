# --- Outputs valides pour ton infrastructure actuelle ---

output "flask_app_url" {
  description = "URL d'accès direct à Flask (sans passer par Nginx)"
  # On récupère le port externe du conteneur Flask (5001 dans ta config actuelle)
  value       = "http://localhost:${docker_container.flask_app.ports[0].external}"
}

output "docker_network_name" {
  description = "Nom du réseau Docker utilisé"
  # On pointe vers 'app_net' comme défini dans main.tf
  value       = docker_network.app_net.name
}

# --- LES OUTPUTS NGINX SONT SUPPRIMÉS ---
# (Car c'est Ansible qui va installer Nginx maintenant, pas Terraform)