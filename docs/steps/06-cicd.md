# 8. Automatisation : CI/CD Local

**Objectif** : Créer un **Makefile** complet pour orchestrer tout le pipeline IaC en une seule commande.

## Contexte

Vous allez créer un Makefile qui automatise :
- `make build` : Build de l'image Docker
- `make infra` : Terraform apply
- `make configure` : Ansible playbook
- `make deploy` : Tout le pipeline (build → infra → configure)
- `make test` : Tests de validation
- `make destroy` : Nettoyage

C'est l'**orchestrateur final** qui simule un pipeline CI/CD.

## Vue d'ensemble

Fichier à créer :
- **`Makefile`** à la racine du projet

Contenu :
- Variables configurables (`WORKSPACE`, `APP_IMAGE`, chemins)
- Targets avec dépendances (ex: `deploy: infra configure`)
- Affichage coloré pour UX
- Gestion d'erreurs avec `||`

## Instructions détaillées

Suivez l'[exercice détaillé Ex06](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex06-chainage-makefile-mini-ci-cd-local/enonce.md) qui explique :

1. **Syntaxe Make** : Targets, dépendances, variables, `.PHONY`
2. **Création du Makefile** avec 10+ targets commentés ligne par ligne
3. **Affichage coloré** : Codes ANSI pour meilleure UX
4. **Gestion d'erreurs** : Fallbacks avec `||`
5. **Pipeline CI/CD** : Enchaînement automatique des étapes

## Instructions rapides

### 1. Créer le Makefile

Créez `Makefile` à la racine avec les targets :
- `help` : Affichage auto-documenté
- `build` : Build image Docker
- `infra` : Terraform (avec dépendance sur `build`)
- `configure` : Ansible playbook
- `deploy` : Chaîne `infra` + `configure`
- `destroy` : Terraform destroy
- `clean` : Destroy + Docker cleanup
- `status` : Affichage état infra
- `test` : Tests curl
- `validate` : Terraform validate + Ansible syntax-check

### 2. Afficher l'aide

```bash
make help
```

### 3. Déploiement complet

Une seule commande pour tout déployer :

```bash
make deploy
```

Cela exécute automatiquement : build → infra → configure.

### 4. Tester

```bash
make test
```

### 5. Voir le statut

```bash
make status
```

### 6. Nettoyer

```bash
make destroy  # Ou make clean pour cleanup complet
```

## 🎉 Félicitations !

Vous avez construit **from scratch** un pipeline IaC complet :
- ✅ Infrastructure as Code (Terraform)
- ✅ Configuration Management (Ansible)
- ✅ Orchestration (Makefile)
- ✅ Multi-environnements (Workspaces)
- ✅ Automatisation end-to-end

Vous avez créé chaque fichier vous-même en comprenant chaque ligne !

> 📚 **Pour aller plus loin** : Consultez l'[exercice détaillé Ex06](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex06-chainage-makefile-mini-ci-cd-local/enonce.md) avec un Makefile complet et des targets avancées.
