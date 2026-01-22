# 4. Terraform : Variables & Workspaces

<!-- INSTRUCTOR:START -->
## Notes formateur
- Timing recommandé : 10 min démo + 15 min pratique
- Piège : `terraform workspace select` oublié → state sur mauvais env
- À insister : `plan` avant `apply`
<!-- INSTRUCTOR:END -->

**Objectif** : Créer le fichier `variables.tf` et utiliser les **workspaces** pour gérer plusieurs environnements (Dev et Prod).

## Contexte

Vous allez rendre votre infrastructure **multi-environnements** :
- **dev** : Nginx sur port `8080`
- **prod** : Nginx sur port `80`

Pour cela, vous créerez un nouveau fichier `variables.tf` et ajouterez des **locals** dans `main.tf` pour calculer les ports dynamiquement.

## Vue d'ensemble

Fichiers à créer/modifier :
1. **`variables.tf`** (nouveau) : Déclare les variables d'entrée
2. **`main.tf`** (modifier) : Ajouter un bloc `locals` et utiliser `local.nginx_port`

## Instructions détaillées

Suivez l'[exercice détaillé Ex02](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex02-terraform-variables-workspaces-dev-prod/enonce.md) qui vous guide dans :

1. **Création de `variables.tf`** avec explication de chaque attribut (`description`, `type`, `default`)
2. **Ajout des locals** dans `main.tf` pour gérer les ports par workspace
3. **Modification des ressources** pour utiliser `${local.env_suffix}` et `local.nginx_port`

## Instructions rapides

### 1. Créer variables.tf

Créez `infra/terraform/variables.tf` avec les variables `project_name`, `app_image`, `app_version`.

### 2. Ajouter locals dans main.tf

Ajoutez un bloc `locals` qui :
- Récupère le workspace actif : `env = terraform.workspace`
- Définit une map de ports : `ports = { dev = 8080, prod = 80 }`
- Calcule le port : `nginx_port = local.ports[local.env]`

### 3. Créer les workspaces

```bash
cd infra/terraform
terraform workspace new dev
terraform workspace new prod
```

### 4. Déployer dev

```bash
terraform workspace select dev
terraform apply
curl http://localhost:8080/health
```

### 5. Déployer prod (en parallèle)

```bash
terraform workspace select prod
terraform apply
curl http://localhost:80/health
```

Les deux environnements coexistent avec 4 conteneurs au total (2 dev + 2 prod).

***

## Points d'attention
- Chaque workspace a son propre fichier d'état (`terraform.tfstate.d/<workspace>/`).
- Une mauvaise gestion des workspaces peut écraser la prod avec une conf de dev si on ne fait pas attention au `select`.

> 📚 **Pour aller plus loin** : Consultez l'[exercice détaillé Ex02](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex02-terraform-variables-workspaces-dev-prod/enonce.md) avec exemples de code HCL complets.

