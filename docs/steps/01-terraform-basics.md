# 3. Terraform : Cycle de vie (Init, Plan, Apply)

<!-- INSTRUCTOR:START -->
## Notes formateur
- Timing recommandé : 10 min démo + 15 min pratique
- Piège : `terraform workspace select` oublié → state sur mauvais env
- À insister : `plan` avant `apply`
<!-- INSTRUCTOR:END -->

**Objectif** : Créer vos premiers fichiers Terraform from scratch et comprendre le cycle de vie IaC (Init, Plan, Apply, Destroy).

## Contexte

Vous allez **créer 3 fichiers Terraform** pour provisionner :
- Un réseau Docker isolé : `devops-local-lab-dev-net`
- Un conteneur pour l'application (Python)
- Un conteneur pour le serveur web (Nginx)

⚠️ **Important** : Le dossier `infra/terraform/` est vide au départ. C'est normal ! Vous allez créer les fichiers étape par étape.

## Vue d'ensemble des fichiers à créer

1. **`versions.tf`** : Déclare la version de Terraform requise
2. **`providers.tf`** : Configure le provider Docker
3. **`main.tf`** : Définit les ressources (réseau, images, conteneurs)

## Instructions rapides

### 1. Créer les fichiers Terraform

Suivez l'[exercice détaillé Ex01](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex01-terraform-hello-infra-plan-apply-destroy/enonce.md) qui vous guide **ligne par ligne** dans la création de :
- `infra/terraform/versions.tf`
- `infra/terraform/providers.tf`
- `infra/terraform/main.tf`

Chaque fichier est expliqué en détail avec la signification de chaque ligne.

### 2. Initialiser Terraform

Une fois vos fichiers créés :

```bash
cd infra/terraform
terraform init
```

Terraform télécharge le provider Docker.

### 3. Valider et formater

```bash
terraform fmt      # Formate le code
terraform validate # Vérifie la syntaxe
```

### 4. Planifier le déploiement

```bash
terraform plan
```

Observez la sortie : Terraform annonce la création de `docker_network`, `docker_image`, `docker_container`.

### 5. Appliquer les changements

```bash
terraform apply
```

Répondez `yes` pour confirmer.

### 6. Vérification

```bash
curl http://localhost:8080/health
# Résultat attendu : {"status":"ok"}

docker ps --format "table {{.Names}}\t{{.Ports}}"
```

### 7. Nettoyage

```bash
terraform destroy
```

***

## Critères de succès
- [ ] La commande `terraform plan` ne retourne pas d'erreur.
- [ ] Après le `apply`, l'URL `http://localhost:8080/health` répond un JSON.
- [ ] Après le `destroy`, `docker ps` ne montre plus les conteneurs du lab.

> 📚 **Pour aller plus loin** : Consultez l'[exercice détaillé Ex01](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex01-terraform-hello-infra-plan-apply-destroy/enonce.md) avec critères de validation complets.

