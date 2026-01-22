# Ex03 — Terraform → Ansible : Générer inventory.ini automatiquement

## 🎯 Objectif pédagogique
Apprendre à **connecter Terraform et Ansible** en automatisant la génération de l'inventaire Ansible depuis les outputs Terraform.

**Concepts couverts** :
- **Outputs Terraform** : Exposer des valeurs calculées
- **Ressource `local_file`** : Générer des fichiers depuis Terraform
- **Templates** : Créer des fichiers dynamiques avec des variables
- **Pipeline IaC** : Provisionner (Terraform) → Configurer (Ansible)

---

## 📋 Prérequis
- Avoir complété Ex01 et Ex02
- Disposer d'une infrastructure Terraform fonctionnelle (réseau + conteneurs)
- Comprendre les bases d'Ansible (on va créer notre premier fichier Ansible)

---

## 🎓 Concepts théoriques

### Qu'est-ce qu'un Inventory Ansible ?
L'**inventory** (inventaire) est un fichier qui liste les **cibles** (hosts) qu'Ansible doit configurer.

**Format INI basique** :
```ini
[vm]                    # Nom du groupe d'hôtes
127.0.0.1               # IP de la cible

[vm:vars]               # Variables pour le groupe "vm"
ansible_user=ansible
ansible_port=2222
```

**Dans notre cas** :
- **Cible** : Un conteneur Docker faisant office de "VM" (avec SSH)
- **Connexion** : Via SSH sur `localhost:2222`
- **Credentials** : User `ansible`, password `ansible`

---

### Pourquoi générer l'inventory depuis Terraform ?

#### ❌ Approche manuelle (problématique)
1. Terraform crée l'infrastructure
2. Vous devez **manuellement** noter les IPs/ports
3. Vous créez à la main `inventory.ini`
4. Risque d'erreur, pas automatisable

#### ✅ Approche automatisée (IaC)
1. Terraform crée l'infrastructure
2. Terraform **génère automatiquement** `inventory.ini` avec les bonnes valeurs
3. Ansible lit directement ce fichier
4. **Zero-touch** : tout est automatique et reproductible

---

### Terraform Outputs : Exposer des valeurs

Les **outputs** permettent d'extraire des informations de Terraform après un `apply` :
- Afficher des valeurs dans le terminal
- Les utiliser dans d'autres modules
- **Générer des fichiers de configuration** (notre cas)

**Exemple** :
```hcl
output "nginx_port" {
  value = local.nginx_port
}
```

Après `terraform apply`, vous verrez :
```
Outputs:
nginx_port = 8080
```

---

## 📝 Énoncé pas à pas

### 📄 Étape 1 : Créer le fichier `outputs.tf`

Les outputs servent à exposer les valeurs importantes de votre infrastructure.

Créez le fichier `infra/terraform/outputs.tf` :

```hcl
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
```

**💡 Explication** :
- `output "environment"` : Affiche le workspace actif (`dev`, `prod`, etc.)
- `output "nginx_port"` : Affiche le port calculé (8080 pour dev, 80 pour prod)
- `value = local.env` : Récupère la valeur depuis les locals définis dans `main.tf`
- `value = docker_network.devops_net.name` : Récupère le nom réel du réseau créé

**✅ Vérification** :
```bash
cd infra/terraform
terraform validate
```

Appliquez pour voir les outputs :
```bash
terraform workspace select dev
terraform apply
```

Vous devriez voir en fin d'apply :
```
Outputs:

docker_network_name = "devops-local-lab-dev-net"
environment = "dev"
nginx_container_name = "devops-local-lab-nginx-dev"
nginx_port = 8080
```

---

### 📁 Étape 2 : Créer la structure Ansible

Ansible s'attend à trouver ses fichiers dans une structure spécifique.

**Créez le dossier et le fichier de configuration** :

```bash
cd /Users/quentinncl/Downloads/devops-local-terraform-ansible/infra
mkdir -p ansible
```

Créez `infra/ansible/ansible.cfg` :

```ini
[defaults]
# Désactive la vérification des clés SSH (pour environnement local uniquement)
host_key_checking = False

# Emplacement de l'inventory
inventory = inventory.ini

# Format de sortie plus lisible
stdout_callback = yaml

# Désactive les avertissements de dépréciation
deprecation_warnings = False
```

**💡 Explication** :
- `host_key_checking = False` : En local, pas besoin de valider les clés SSH
- `inventory = inventory.ini` : Fichier d'inventaire par défaut
- `stdout_callback = yaml` : Affichage plus propre des résultats

---

### 📐 Étape 3 : Générer l'inventory avec Terraform

On va créer une **ressource `local_file`** qui génère `inventory.ini` automatiquement.

**Ouvrez `infra/terraform/main.tf` et ajoutez à la fin** :

```hcl
# Génération automatique de l'inventory Ansible
resource "local_file" "ansible_inventory" {
  # Chemin relatif : depuis terraform/ vers ansible/inventory.ini
  filename = "${path.module}/../ansible/inventory.ini"
  
  # Contenu du fichier généré
  content = <<-EOT
    # Inventory Ansible généré automatiquement par Terraform
    # Environnement : ${local.env}
    # Date de génération : ${timestamp()}

    [vm]
    127.0.0.1 ansible_port=2222 ansible_user=ansible ansible_password=ansible ansible_connection=ssh

    [vm:vars]
    ansible_python_interpreter=/usr/bin/python3
    ansible_become=yes
    ansible_become_method=sudo
    ansible_become_pass=ansible
  EOT
  
  # Permissions du fichier (rw-r--r--)
  file_permission = "0644"
}
```

**💡 Explication ligne par ligne** :
- `resource "local_file"` : Ressource Terraform pour créer un fichier local
- `filename = "${path.module}/../ansible/inventory.ini"` :
  - `${path.module}` = chemin du dossier contenant le fichier `.tf` (`infra/terraform/`)
  - `/../ansible/` = remonte d'un niveau puis entre dans `ansible/`
- `content = <<-EOT ... EOT` : Heredoc pour contenu multi-lignes
- `[vm]` : Groupe d'hôtes Ansible nommé "vm"
- `127.0.0.1` : Cible SSH (localhost, car conteneur Docker mappé)
- `ansible_port=2222` : Port SSH du conteneur
- `ansible_user=ansible` : Utilisateur SSH
- `ansible_connection=ssh` : Force la connexion SSH (sinon Ansible pourrait utiliser `local`)
- `[vm:vars]` : Variables applicables à tout le groupe "vm"
- `ansible_become=yes` : Permet l'élévation de privilèges (sudo)

---

### 🚀 Étape 4 : Appliquer et vérifier la génération

**Appliquez Terraform** :
```bash
cd infra/terraform
terraform workspace select dev
terraform apply
```

**Vérifiez que le fichier a été créé** :
```bash
cat ../ansible/inventory.ini
```

**Résultat attendu** :
```ini
# Inventory Ansible généré automatiquement par Terraform
# Environnement : dev
# Date de génération : 2026-01-22T12:00:00Z

[vm]
127.0.0.1 ansible_port=2222 ansible_user=ansible ansible_password=ansible ansible_connection=ssh

[vm:vars]
ansible_python_interpreter=/usr/bin/python3
ansible_become=yes
ansible_become_method=sudo
ansible_become_pass=ansible
```

---

### 🧪 Étape 5 : Tester la connexion Ansible (simulation)

Pour l'instant, **nous n'avons pas encore de conteneur SSH**, mais on peut vérifier la syntaxe :

```bash
cd ../ansible
ansible-inventory -i inventory.ini --list
```

**Résultat attendu** :
```json
{
    "_meta": {
        "hostvars": {
            "127.0.0.1": {
                "ansible_become": "yes",
                "ansible_become_method": "sudo",
                "ansible_become_pass": "ansible",
                "ansible_connection": "ssh",
                "ansible_password": "ansible",
                "ansible_port": 2222,
                "ansible_python_interpreter": "/usr/bin/python3",
                "ansible_user": "ansible"
            }
        }
    },
    "all": {
        "children": [
            "ungrouped",
            "vm"
        ]
    },
    "vm": {
        "hosts": [
            "127.0.0.1"
        ]
    }
}
```

**💡 Interprétation** :
- Ansible a bien parsé le fichier INI
- Le groupe `vm` contient 1 host (`127.0.0.1`)
- Toutes les variables sont bien associées

---

### 🔄 Étape 6 : Vérifier l'idempotence

Relancez `terraform apply` plusieurs fois :

```bash
cd ../terraform
terraform apply
terraform apply
terraform apply
```

**Résultat attendu** :
```
No changes. Infrastructure is up-to-date.
```

**Sauf si** : Le `timestamp()` change à chaque apply ! 

**🔧 Correction** : Supprimez la ligne `# Date de génération : ${timestamp()}` pour éviter les modifications inutiles.

**Modifiez `main.tf`** :
```hcl
content = <<-EOT
  # Inventory Ansible généré automatiquement par Terraform
  # Environnement : ${local.env}

  [vm]
  127.0.0.1 ansible_port=2222 ansible_user=ansible ansible_password=ansible ansible_connection=ssh
  
  [vm:vars]
  ansible_python_interpreter=/usr/bin/python3
  ansible_become=yes
  ansible_become_method=sudo
  ansible_become_pass=ansible
EOT
```

Relancez `terraform apply` :
```bash
terraform apply
```

Maintenant, Terraform devrait détecter le changement (suppression de la ligne timestamp), l'appliquer, puis être idempotent aux prochains apply.

---

### 🎯 Étape 7 : Rendre l'inventory dynamique (bonus)

Actuellement, le port SSH est **codé en dur** (2222). Rendons-le dynamique !

**Ajoutez un local dans `main.tf`** :
```hcl
locals {
  env = terraform.workspace

  ports = {
    default = 8080
    dev     = 8080
    prod    = 80
  }

  nginx_port = local.ports[local.env]
  env_suffix = local.env == "default" ? "" : "-${local.env}"
  
  # 👇 NOUVEAU : Port SSH dynamique
  ssh_port = 2222
}
```

**Modifiez la ressource `local_file`** :
```hcl
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
```

**Changement** : `ansible_port=2222` → `ansible_port=${local.ssh_port}`

Maintenant, si vous changez `ssh_port = 2223`, l'inventory sera automatiquement mis à jour !

---

### 🧹 Étape 8 : Nettoyer

```bash
cd infra/terraform
terraform destroy
```

**Note** : Par défaut, Terraform **ne supprime pas** les fichiers créés par `local_file` lors d'un `destroy`. Le fichier `inventory.ini` persistera. C'est le comportement attendu (l'inventory peut servir même après destruction de l'infra).

Pour forcer la suppression, il faudrait utiliser un `provisioner "local-exec" { when = destroy }`.

---

## ✅ Critères de réussite

### Fichiers créés
- [ ] `infra/terraform/outputs.tf` existe avec 4 outputs déclarés
- [ ] `infra/ansible/ansible.cfg` existe avec la configuration de base
- [ ] `infra/ansible/inventory.ini` est **généré automatiquement** après `terraform apply`

### Outputs Terraform
- [ ] `terraform output` affiche `environment`, `nginx_port`, `docker_network_name`, `nginx_container_name`
- [ ] Les valeurs affichées sont cohérentes avec le workspace actif

### Inventory Ansible
- [ ] `cat infra/ansible/inventory.ini` montre un fichier au format INI valide
- [ ] Le fichier contient le groupe `[vm]` avec l'host `127.0.0.1`
- [ ] Les variables SSH sont présentes : `ansible_port`, `ansible_user`, `ansible_password`
- [ ] `ansible-inventory -i inventory.ini --list` parse correctement le fichier (format JSON valide)

### Idempotence
- [ ] `terraform apply` exécuté plusieurs fois de suite indique `No changes` (après correction du timestamp)
- [ ] Le contenu de `inventory.ini` ne change pas entre deux apply successifs

### Qualité du code
- [ ] `terraform fmt` ne modifie rien
- [ ] `terraform validate` passe sans erreur

---

## 💡 Points clés à retenir

1. **Outputs** : Exposent des valeurs Terraform pour consommation externe
2. **`local_file`** : Crée des fichiers locaux depuis Terraform (configs, scripts, etc.)
3. **`${path.module}`** : Chemin absolu du dossier contenant le fichier `.tf`
4. **Heredoc `<<-EOT`** : Syntaxe pour contenu multi-lignes
5. **Pipeline IaC** : Terraform génère → Ansible consomme → Automatisation complète
6. **Idempotence** : Éviter les valeurs changeantes (timestamps) dans les contenus générés

---

## 🚨 Pièges courants

### ❌ Chemin relatif incorrect
```hcl
# MAUVAIS : Ne fonctionne que si vous êtes dans terraform/
filename = "../ansible/inventory.ini"

# BON : Utilise le chemin absolu du module
filename = "${path.module}/../ansible/inventory.ini"
```

### ❌ Oublier `ansible_connection=ssh`
Sans cette variable, Ansible pourrait tenter une connexion `local` et ignorer `ansible_port` :
```ini
# MAUVAIS
[vm]
127.0.0.1 ansible_port=2222

# BON
[vm]
127.0.0.1 ansible_port=2222 ansible_connection=ssh
```

### ❌ Indentation incorrecte dans le heredoc
Le format INI est sensible à l'indentation. Avec `<<-EOT`, l'indentation est supprimée, mais attention aux espaces en début de ligne :

```hcl
# MAUVAIS : Espaces avant [vm] cassent le format INI
content = <<-EOT
    [vm]
    127.0.0.1
EOT

# BON : Pas d'espaces avant les sections INI
content = <<-EOT
[vm]
127.0.0.1
EOT
```

### ❌ Timestamp qui casse l'idempotence
```hcl
# MAUVAIS : Le fichier change à chaque apply
content = "Generated at ${timestamp()}"

# BON : Contenu stable
content = "Generated by Terraform"
```

---

## 🔗 Étapes suivantes
➡️ [Ex04 : Ansible bootstrap Docker + déploiement app](../ex04-ansible-bootstrap-docker-deploiement-app-idempotence/enonce.md)

---

## 📚 Ressources complémentaires
- [Terraform Outputs](https://developer.hashicorp.com/terraform/language/values/outputs)
- [Terraform local_file](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file)
- [Ansible Inventory Format](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html)
- [Terraform Functions - path.module](https://developer.hashicorp.com/terraform/language/expressions/references#filesystem-and-workspace-info)
- [Heredoc Syntax](https://developer.hashicorp.com/terraform/language/expressions/strings#heredoc-strings)
