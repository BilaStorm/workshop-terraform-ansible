# Ex02 — Terraform : Variables + Workspaces (dev/prod)

## 🎯 Objectif pédagogique
Apprendre à **gérer plusieurs environnements** avec Terraform en utilisant :
- **Workspaces** : isoler les états Terraform (dev vs prod)
- **Variables** : rendre le code configurable
- **Locals** : calculer des valeurs réutilisables

Vous allez transformer votre infrastructure mono-environnement en une infrastructure multi-environnements (dev/prod) avec des ports différents.

---

## 📋 Prérequis
- Avoir complété l'Ex01 avec succès
- Disposer des 3 fichiers Terraform : `versions.tf`, `providers.tf`, `main.tf`
- Comprendre les bases de Terraform (plan, apply, destroy)

---

## 🎓 Concepts théoriques

### Qu'est-ce qu'un Workspace ?
Un **workspace** est une **instance isolée** d'une même configuration Terraform :
- Chaque workspace a son propre fichier d'état (`.tfstate`)
- Permet de déployer la même infrastructure dans différents environnements
- Par défaut, vous êtes sur le workspace `default`

**Exemple** : 
- Workspace `dev` → Nginx sur port 8080
- Workspace `prod` → Nginx sur port 80
- Même code, états différents, configurations différentes

### Variables vs Locals
| Type | Usage | Déclaration | Valeur |
|------|-------|-------------|--------|
| **variable** | Input externe | `variable "name" {}` | Définie par l'utilisateur ou `.tfvars` |
| **local** | Calcul interne | `locals { name = ... }` | Calculée à partir d'autres valeurs |

**Dans cet exercice** :
- On utilisera `terraform.workspace` (variable système) pour connaître l'environnement actif
- On créera des `locals` pour calculer les ports selon l'environnement

---

## 📝 Énoncé pas à pas

### 📁 Étape 1 : Créer le fichier `variables.tf`

Ce fichier déclare les variables d'entrée de votre infrastructure.

Créez le fichier `infra/terraform/variables.tf` :

```hcl
# variables.tf
# Déclaration des variables d'entrée pour rendre l'infrastructure configurable

variable "project_name" {
  description = "Nom du projet (utilisé comme préfixe pour les ressources)"
  type        = string
  default     = "devops-local-lab"
}

variable "app_image" {
  description = "Image Docker de l'application Flask"
  type        = string
  default     = "devops-local-app"
}

variable "app_version" {
  description = "Version de l'application"
  type        = string
  default     = "latest"
}
```

**💡 Explication ligne par ligne** :
- `variable "project_name"` : Déclare une variable nommée `project_name`
- `description` : Documentation pour les utilisateurs
- `type = string` : Force le type (ici, une chaîne de caractères)
- `default = "..."` : Valeur par défaut si non fournie

**✅ Vérification** :
```bash
cd infra/terraform
terraform validate
```

---

### 📐 Étape 2 : Ajouter des `locals` dans `main.tf`

Les `locals` permettent de calculer des valeurs en fonction du workspace actif.

**Ouvrez `main.tf` et ajoutez ce bloc au début** (juste après le bloc `terraform {}`) :

```hcl
# Calcul de variables locales selon l'environnement (workspace)
locals {
  # Récupère le workspace actif (dev, prod, ou default)
  env = terraform.workspace

  # Définit les ports par environnement
  ports = {
    default = 8080
    dev     = 8080
    prod    = 80
  }

  # Sélectionne le port correspondant à l'environnement actif
  nginx_port = local.ports[local.env]

  # Génère un suffixe pour les noms de ressources
  env_suffix = local.env == "default" ? "" : "-${local.env}"
}
```

**💡 Explication** :
- `terraform.workspace` : Variable système Terraform donnant le nom du workspace actif
- `local.ports` : Map (dictionnaire) associant chaque environnement à un port
- `local.ports[local.env]` : Accède au port correspondant (ex: `dev` → `8080`)
- Expression ternaire `condition ? valeur_si_vrai : valeur_si_faux`

---

### 🔧 Étape 3 : Modifier les ressources pour utiliser les variables

**3a) Modifier le nom du réseau Docker**

Trouvez le bloc `resource "docker_network"` dans `main.tf` et modifiez-le :

```hcl
resource "docker_network" "devops_net" {
  name = "${var.project_name}${local.env_suffix}-net"
}
```

**Avant** : `"devops-local-lab-net"`  
**Après en dev** : `"devops-local-lab-dev-net"`  
**Après en prod** : `"devops-local-lab-prod-net"`

---

**3b) Modifier le conteneur Nginx**

Trouvez le bloc `resource "docker_container" "nginx"` et modifiez :

```hcl
resource "docker_container" "nginx" {
  name  = "${var.project_name}-nginx${local.env_suffix}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = local.nginx_port  # 👈 Port dynamique selon l'environnement
  }

  networks_advanced {
    name = docker_network.devops_net.name
  }

  # Configuration Nginx minimale pour test
  upload {
    content = <<-EOF
      server {
        listen 80;
        location /health {
          return 200 '{"status":"ok"}';
          add_header Content-Type application/json;
        }
      }
    EOF
    file    = "/etc/nginx/conf.d/default.conf"
  }
}
```

**💡 Changements** :
- `name` : Inclut maintenant `${local.env_suffix}` → `-dev` ou `-prod`
- `external = local.nginx_port` : Port calculé selon l'environnement

---

**3c) Appliquer le même principe au conteneur Flask (si présent)**

Si vous avez un conteneur Flask/app, modifiez-le aussi :

```hcl
resource "docker_container" "app" {
  name  = "${var.project_name}-app${local.env_suffix}"
  image = docker_image.app.image_id
  
  # ... reste de la configuration
}
```

---

### 🚀 Étape 4 : Créer les workspaces

Terraform démarre avec un workspace `default`. Créons `dev` et `prod` :

```bash
cd infra/terraform

# Lister les workspaces existants
terraform workspace list

# Créer le workspace dev
terraform workspace new dev

# Créer le workspace prod
terraform workspace new prod

# Revenir sur dev
terraform workspace select dev
```

**💡 Vérification** :
```bash
terraform workspace list
```

Vous devriez voir :
```
  default
* dev       # L'astérisque indique le workspace actif
  prod
```

---

### 🔥 Étape 5 : Déployer l'environnement dev

**Assurez-vous d'être sur le workspace dev** :

```bash
terraform workspace select dev
terraform init  # Rafraîchit le backend
terraform plan  # Prévisualisation
terraform apply -auto-approve
```

**✅ Vérification** :
```bash
# Tester l'API Health
curl http://localhost:8080/health

# Vérifier les conteneurs créés
docker ps --filter "name=dev"
```

**Résultat attendu** :
```json
{"status":"ok"}
```

Et vous devriez voir des conteneurs avec `-dev` dans leur nom.

---

### 🏭 Étape 6 : Déployer l'environnement prod (en parallèle)

**Basculez sur le workspace prod** :

```bash
terraform workspace select prod
terraform plan
terraform apply -auto-approve
```

**✅ Vérification** :
```bash
# Tester l'API Health (port 80 !)
curl http://localhost:80/health
# Ou simplement :
curl http://localhost/health

# Vérifier les conteneurs prod
docker ps --filter "name=prod"
```

**Vérification globale** :
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Vous devriez voir **4 conteneurs** :
- `devops-local-lab-nginx-dev` → port 8080
- `devops-local-lab-app-dev`
- `devops-local-lab-nginx-prod` → port 80
- `devops-local-lab-app-prod`

---

### 🗂️ Étape 7 : Explorer les fichiers d'état

Chaque workspace a son propre fichier d'état :

```bash
ls -la .terraform/terraform.tfstate.d/
```

Vous verrez :
```
dev/terraform.tfstate
prod/terraform.tfstate
```

**💡 Concept clé** : Les deux environnements sont complètement isolés. Détruire l'un n'affecte pas l'autre.

---

### 🧹 Étape 8 : Nettoyer les environnements

**Détruire dev** :
```bash
terraform workspace select dev
terraform destroy -auto-approve
```

**Détruire prod** :
```bash
terraform workspace select prod
terraform destroy -auto-approve
```

**Vérification finale** :
```bash
docker ps  # Devrait être vide
```

---

## ✅ Critères de réussite

### Fichiers créés
- [ ] `infra/terraform/variables.tf` existe avec 3 variables déclarées
- [ ] `infra/terraform/main.tf` contient un bloc `locals {}` avec les maps de ports

### Workspaces
- [ ] `terraform workspace list` affiche `dev`, `prod` et `default`
- [ ] Chaque workspace a son propre état (fichier `.tfstate` séparé)

### Environnement dev
- [ ] `curl http://localhost:8080/health` retourne `{"status":"ok"}`
- [ ] Conteneurs nommés `*-dev` visibles dans `docker ps`

### Environnement prod
- [ ] `curl http://localhost:80/health` retourne `{"status":"ok"}`
- [ ] Conteneurs nommés `*-prod` visibles dans `docker ps`

### Coexistence
- [ ] Les deux environnements fonctionnent **simultanément** sans conflit
- [ ] `docker ps` montre 4 conteneurs (2 dev + 2 prod)
- [ ] Les ports 80 et 8080 sont tous deux accessibles

### Qualité du code
- [ ] `terraform fmt` ne modifie rien (code déjà formaté)
- [ ] `terraform validate` passe sans erreur

---

## 💡 Points clés à retenir

1. **Workspaces = États isolés** : Même configuration, états différents
2. **`terraform.workspace`** : Variable système donnant le workspace actif
3. **Locals vs Variables** :
   - `variable` : Input utilisateur (externe)
   - `local` : Calcul interne (dérivé)
4. **Nommage avec suffixes** : Évite les collisions entre environnements
5. **Un workspace = un `.tfstate`** : Destruction indépendante

---

## 🚨 Pièges courants

### ❌ Oublier de sélectionner le workspace
```bash
# MAUVAIS : vous êtes peut-être sur prod !
terraform apply
```

```bash
# BON : toujours vérifier/sélectionner
terraform workspace select dev
terraform apply
```

### ❌ Conflits de ports
Si dev et prod utilisent le même port, Docker échouera :
```
Error: port 8080 already allocated
```

**Solution** : Utiliser `local.ports` pour différencier.

### ❌ Oublier le suffixe dans les noms
Si vous nommez tous les conteneurs `nginx`, ils entreront en conflit :
```
Error: container name "nginx" already in use
```

**Solution** : Toujours inclure `${local.env_suffix}` dans les noms.

---

## 🔗 Étapes suivantes
➡️ [Ex03 : Générer l'inventory Ansible automatiquement](../ex03-terraform-ansible-generer-inventory-ini-automatiquement/enonce.md)

---

## 📚 Ressources complémentaires
- [Terraform Workspaces - Documentation officielle](https://developer.hashicorp.com/terraform/language/state/workspaces)
- [Input Variables](https://developer.hashicorp.com/terraform/language/values/variables)
- [Local Values](https://developer.hashicorp.com/terraform/language/values/locals)
- [Interpolation avec `${}`](https://developer.hashicorp.com/terraform/language/expressions/strings#interpolation)
