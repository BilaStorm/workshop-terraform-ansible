# 5. Terraform → Ansible : Inventaire Dynamique

**Objectif** : Créer `outputs.tf` et générer automatiquement le fichier `inventory.ini` d'Ansible depuis Terraform.

## Contexte

Vous allez **connecter Terraform et Ansible** en automatisant la génération de l'inventaire :
- Terraform connaît les IPs/ports après le déploiement
- Il génère automatiquement `infra/ansible/inventory.ini`
- Ansible peut immédiatement l'utiliser

## Vue d'ensemble

Fichiers à créer :
1. **`outputs.tf`** (nouveau) : Expose les valeurs importantes (ports, noms de conteneurs)
2. **`ansible/ansible.cfg`** (nouveau) : Configuration Ansible de base
3. Modification de **`main.tf`** : Ajouter une ressource `local_file` pour générer l'inventory

## Instructions détaillées

Suivez l'[exercice détaillé Ex03](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex03-terraform-ansible-generer-inventory-ini-automatiquement/enonce.md) qui explique :

1. **Création de `outputs.tf`** : Définir les outputs (environment, nginx_port, network_name)
2. **Création de `ansible.cfg`** : Configuration de base Ansible
3. **Ajout de `local_file`** dans `main.tf` : Génération automatique de `inventory.ini`

## Instructions rapides

### 1. Créer outputs.tf

Créez `infra/terraform/outputs.tf` avec des outputs pour exposer :
- `environment` (workspace actif)
- `nginx_port` (port calculé)
- `docker_network_name`
- `nginx_container_name`

### 2. Créer ansible.cfg

Créez `infra/ansible/ansible.cfg` avec la configuration de base.

### 3. Ajouter local_file dans main.tf

Ajoutez une ressource `local_file` qui génère `../ansible/inventory.ini` avec le format INI approprié.

### 4. Appliquer et vérifier

```bash
cd infra/terraform
terraform apply
cat ../ansible/inventory.ini  # Fichier généré automatiquement !
```

### 5. Valider l'inventory

```bash
cd ../ansible
ansible-inventory -i inventory.ini --list
```

Cette commande parse l'inventory et affiche sa structure en JSON.

> 📚 **Pour aller plus loin** : Consultez l'[exercice détaillé Ex03](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex03-terraform-ansible-generer-inventory-ini-automatiquement/enonce.md) pour comprendre la génération dynamique d'inventory.
