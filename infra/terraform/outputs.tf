# --- Outputs valides ---

output "docker_network_name" {
  description = "Nom du réseau Docker utilisé"
  # On pointe vers 'app_net' comme défini dans main.tf
  value = docker_network.app_net.name
}

# L'URL de l'application sera disponible une fois Ansible terminé
# via http://localhost:5000 (Flask) ou http://localhost:80 (Nginx)