# Ex01 — Terraform : Hello Infra (plan/apply/destroy)

## 🎯 Objectif
Découvrir le cycle de vie Terraform de base : **init → plan → apply → destroy**.  
Vous allez **CRÉER** votre premier fichier Terraform et provisionner une infrastructure Docker locale avec :
- Un réseau Docker
- Un conteneur Flask (l'app)
- Un conteneur Nginx (reverse proxy)

## 📝 Énoncé

### Préambule : Comprendre la structure

Terraform organise le code en plusieurs fichiers `.tf` :
- `versions.tf` : Versions de Terraform et providers requis
- `providers.tf` : Configuration des providers (ici Docker)
- `main.tf` : Ressources principales (réseau, conteneurs)
- `variables.tf` : Variables configurables (Ex02)
- `outputs.tf` : Valeurs exportées (Ex03)

**Dans cet exercice, nous créons les 3 premiers.**

---

### Étape 1 : Build de l'image Docker de l'app

Avant de provisionner l'infra, construisez l'image de l'application Flask :

```bash
docker build -t devops-local-lab-flask:latest app/
```

**Vérification** : 
```bash
docker images | grep devops-local-lab-flask
# Doit afficher : devops-local-lab-flask   latest   ...
```

---

### Étape 2 : Créer le dossier de travail

```bash
cd infra/terraform
pwd
# Doit afficher : .../infra/terraform
```

---

### Étape 3 : Créer `versions.tf`

Ce fichier définit les versions minimales de Terraform et des providers.

**Créez le fichier `infra/terraform/versions.tf`** :

```hcl
terraform {
  required_version = ">= 1.0"

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
```

**💡 Explications** :
- `required_version` : Version minimale de Terraform
- `required_providers` : Liste des providers nécessaires
- `docker` : Provider pour gérer des ressources Docker
- `local` : Provider pour gérer des fichiers locaux (utilisé plus tard)

---

### Étape 4 : Créer `providers.tf`

Ce fichier configure les providers déclarés dans `versions.tf`.

**Créez le fichier `infra/terraform/providers.tf`** :

```hcl
provider "docker" {
  host = "unix:///var/run/docker.sock"
}
```

**💡 Explications** :
- `host` : Socket Docker local (standard sur Linux/macOS)
- Sur Windows/WSL, c'est aussi `/var/run/docker.sock` via WSL2

---

### Étape 5 : Créer `main.tf` — Le cœur de l'infrastructure

C'est ici que vous déclarez les ressources à créer.

**Créez le fichier `infra/terraform/main.tf`** :

```hcl
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
```

**💡 Explications détaillées** :

#### Locals
- `project` : Nom du projet (préfixe pour toutes les ressources)
- `env` : Environnement (hardcodé pour l'instant, sera une variable en Ex02)
- `app_image` : Nom complet de l'image Docker

#### Ressource 1 : `docker_network`
- Crée un réseau isolé pour que les conteneurs communiquent entre eux
- Les conteneurs peuvent se résoudre par leur nom (DNS interne)

#### Ressource 2 : `docker_container.flask_app`
- Lance l'application Flask
- `networks_advanced` : Attache au réseau créé
- `env` : Variables d'environnement injectées dans le conteneur
- `ports` : Expose le port 5000 en interne ET externe (temporaire, en prod on n'exposerait que via Nginx)

#### Ressource 3 : `docker_image.nginx`
- Pull l'image Nginx officielle depuis Docker Hub
- Terraform gère le téléchargement

#### Ressource 4 : `local_file.nginx_conf`
- **GÉNÈRE** un fichier de config Nginx dynamiquement
- `${path.module}` : Chemin du dossier contenant le `.tf`
- Le heredoc `<<-EOT` permet du multiline
- `${docker_container.flask_app.name}` : Référence au nom du conteneur app (résolution DNS Docker)

#### Ressource 5 : `docker_container.nginx`
- Lance Nginx en reverse proxy
- `volumes` : Monte le fichier de config généré dans le conteneur
- `abspath()` : Convertit le chemin relatif en absolu (requis par Docker)
- `depends_on` : S'assure que le fichier et l'app existent avant de démarrer Nginx

---

### Étape 6 : Créer le dossier `generated/`

Terraform va générer des fichiers dedans.

```bash
mkdir -p generated
echo "*" > generated/.gitignore
```

**💡 Pourquoi ?**
- Le dossier `generated/` contiendra des fichiers créés par Terraform
- On l'ignore dans Git car ce sont des artefacts générés

---

### Étape 7 : Initialiser Terraform

Téléchargez les providers :

```bash
terraform init
```

**Résultat attendu** :
```
Initializing the backend...
Initializing provider plugins...
- Installing kreuzwerker/docker v3.x.x...
- Installing hashicorp/local v2.x.x...

Terraform has been successfully initialized!
```

---

### Étape 8 : Planifier les changements

Visualisez ce que Terraform va créer **SANS rien créer** :

```bash
terraform plan
```

**Résultat attendu** :
```
Plan: 5 to add, 0 to change, 0 to destroy.
```

---

### Étape 9 : Appliquer l'infrastructure

Créez réellement les ressources :

```bash
terraform apply
```

Tapez `yes` pour confirmer.

**Résultat attendu** :
```
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

---

### Étape 10 : Tester l'application

Testez le endpoint de santé via Nginx :

```bash
curl http://localhost:8080/health
```

**Résultat attendu** :
```json
{"status":"ok"}
```

---

### Étape 11 : Détruire l'infrastructure

Supprimez toutes les ressources créées :

```bash
terraform destroy
```

Tapez `yes` pour confirmer.

---

## ✅ Critères de réussite

- [ ] Fichier `versions.tf` créé avec providers docker et local
- [ ] Fichier `providers.tf` créé avec config Docker
- [ ] Fichier `main.tf` créé avec 5 ressources
- [ ] `terraform init` réussit sans erreur
- [ ] `terraform plan` affiche 5 ressources à créer
- [ ] `terraform apply` crée les ressources sans erreur
- [ ] `curl http://localhost:8080/health` retourne `{"status":"ok"}`
- [ ] `docker ps` affiche 2 conteneurs : app et nginx
- [ ] Fichier `generated/nginx.conf` existe et contient la config
- [ ] `terraform destroy` supprime toutes les ressources

---

## 💡 Points clés à retenir

- **init** : Télécharge les providers
- **plan** : Preview des changements (n'applique rien)
- **apply** : Crée/modifie les ressources
- **destroy** : Supprime tout ce que Terraform gère
- Le fichier `terraform.tfstate` stocke l'état actuel de l'infra

---

## 📚 Ressources

- [Terraform CLI Commands](https://www.terraform.io/cli/commands)
- [Docker Provider](https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs)
