# Ex06 — Chaînage : Makefile (mini CI/CD local)

## 🎯 Objectif pédagogique
Apprendre à **orchestrer un pipeline IaC complet** avec Make, en automatisant toutes les étapes du cycle de vie de l'infrastructure.

**Concepts couverts** :
- **Make** : Outil d'automatisation universel
- **Targets** : Commandes réutilisables
- **Dépendances** : Chaînage de tâches
- **Variables** : Configuration flexible
- **Pipeline CI/CD** : Build → Provision → Configure → Deploy

---

## 📋 Prérequis
- Avoir complété Ex01 à Ex05
- Disposer d'une infrastructure Terraform + Ansible fonctionnelle
- Comprendre les commandes shell de base

---

## 🎓 Concepts théoriques

### Qu'est-ce que Make ?

**Make** est un outil d'automatisation créé en 1976, toujours largement utilisé :
- **Universel** : Fonctionne sur tous les systèmes Unix/Linux/macOS
- **Simple** : Syntaxe déclarative claire
- **Puissant** : Gestion des dépendances automatique

**Exemple** :
```makefile
deploy: build test
	echo "Déploiement..."
```

Exécuter `make deploy` :
1. Exécute `build`
2. Exécute `test`
3. Exécute `deploy`

---

### Anatomie d'un Makefile

```makefile
# Commentaire

VARIABLE = valeur

target: dependance1 dependance2  ## Description
	commande1
	commande2
```

**Composants** :
- `VARIABLE` : Variable réutilisable (`$(VARIABLE)`)
- `target` : Nom de la commande (`make target`)
- `dependance` : Targets à exécuter avant
- Commandes : **ATTENTION, utiliser des TABS, pas des espaces !**
- `##` : Description pour `make help`

---

### .PHONY : Targets virtuels

```makefile
.PHONY: deploy clean
```

**Sans `.PHONY`** : Make cherche un fichier nommé `deploy`  
**Avec `.PHONY`** : `deploy` est un target virtuel, pas un fichier

**💡 Règle** : Toujours déclarer les targets qui ne produisent pas de fichiers.

---

### Pipeline IaC avec Make

```
make deploy
    ↓
  build (image Docker)
    ↓
  infra (Terraform apply)
    ↓
  configure (Ansible playbook)
    ↓
  test (curl health)
```

---

## 📝 Énoncé pas à pas

### 📄 Étape 1 : Créer le Makefile racine

Créez le fichier `Makefile` **à la racine du projet** :

```makefile
# Makefile — Orchestration IaC DevOps Local Lab
# Gère le cycle de vie complet : build, provision, configure, deploy, destroy

.PHONY: help build infra configure deploy destroy clean status test

# Variables configurables
WORKSPACE ?= dev
APP_IMAGE = devops-local-app:latest
TERRAFORM_DIR = infra/terraform
ANSIBLE_DIR = infra/ansible

# Couleurs pour l'affichage
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;36m
NC = \033[0m  # No Color

help: ## Affiche cette aide
	@echo "$(BLUE)Commandes disponibles :$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

build: ## Build l'image Docker de l'application
	@echo "$(YELLOW)🔨 Building application image...$(NC)"
	docker build -t $(APP_IMAGE) app/
	@echo "$(GREEN)✅ Image built: $(APP_IMAGE)$(NC)"

infra: build ## Provisionne l'infrastructure avec Terraform
	@echo "$(YELLOW)🚀 Provisioning infrastructure (workspace: $(WORKSPACE))...$(NC)"
	cd $(TERRAFORM_DIR) && \
		terraform workspace select $(WORKSPACE) 2>/dev/null || terraform workspace new $(WORKSPACE) && \
		terraform init -upgrade && \
		terraform fmt && \
		terraform validate && \
		terraform apply -auto-approve
	@echo "$(GREEN)✅ Infrastructure provisioned$(NC)"

configure: ## Configure la VM avec Ansible
	@echo "$(YELLOW)⚙️  Configuring VM with Ansible...$(NC)"
	cd $(ANSIBLE_DIR) && \
		ansible-playbook -i inventory.ini site.yml
	@echo "$(GREEN)✅ Configuration applied$(NC)"

deploy: infra configure ## Déploie tout (infra + config) en une commande
	@echo "$(GREEN)✅ Deployment complete!$(NC)"
	@echo "$(BLUE)Test with: make test$(NC)"

destroy: ## Détruit l'infrastructure Terraform
	@echo "$(RED)🗑️  Destroying infrastructure (workspace: $(WORKSPACE))...$(NC)"
	cd $(TERRAFORM_DIR) && \
		terraform workspace select $(WORKSPACE) && \
		terraform destroy -auto-approve
	@echo "$(GREEN)✅ Infrastructure destroyed$(NC)"

clean: destroy ## Nettoyage complet (destroy + Docker cleanup)
	@echo "$(RED)🧹 Cleaning up Docker resources...$(NC)"
	docker system prune -f --volumes
	@echo "$(GREEN)✅ Cleanup complete!$(NC)"

status: ## Affiche le statut de l'infrastructure
	@echo "$(BLUE)📊 Infrastructure Status$(NC)"
	@echo "\n$(YELLOW)Docker containers:$(NC)"
	@docker ps --filter "name=devops-local-lab" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers"
	@echo "\n$(YELLOW)Terraform workspace:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform workspace show 2>/dev/null || echo "Not initialized"
	@echo "\n$(YELLOW)Terraform resources:$(NC)"
	@cd $(TERRAFORM_DIR) && terraform state list 2>/dev/null || echo "No state"

test: ## Teste l'application déployée
	@echo "$(BLUE)🧪 Testing deployed application...$(NC)"
	@curl -sf http://localhost:8080/health | jq . && \
		echo "$(GREEN)✅ Health check passed$(NC)" || \
		echo "$(RED)❌ Health check failed$(NC)"

validate: ## Valide la configuration (Terraform + Ansible)
	@echo "$(BLUE)🔍 Validating Terraform...$(NC)"
	cd $(TERRAFORM_DIR) && terraform fmt -check && terraform validate
	@echo "$(BLUE)🔍 Validating Ansible...$(NC)"
	cd $(ANSIBLE_DIR) && ansible-playbook --syntax-check site.yml
	@echo "$(GREEN)✅ Validation passed$(NC)"

logs: ## Affiche les logs de l'application
	@docker logs -f devops-local-lab-app-dev 2>/dev/null || \
		echo "$(RED)Container not found. Try: make status$(NC)"
```

**💡 Explication des sections** :

### Variables
```makefile
WORKSPACE ?= dev
```
- `?=` : Définit la valeur **si non déjà définie**
- Permet : `make deploy WORKSPACE=prod`

### Cibles avec dépendances
```makefile
deploy: infra configure
```
- Exécute `infra`, puis `configure`, puis `deploy`

### Affichage coloré
```makefile
@echo "$(GREEN)✅ Success$(NC)"
```
- `@` : N'affiche pas la commande elle-même
- `$(GREEN)` : Code ANSI pour couleur verte

### Gestion d'erreurs
```makefile
terraform workspace select $(WORKSPACE) 2>/dev/null || terraform workspace new $(WORKSPACE)
```
- `2>/dev/null` : Masque les erreurs
- `||` : Si échec, exécute la commande suivante

---

### 🧪 Étape 2 : Tester l'aide

```bash
make help
```

**Résultat attendu** :
```
Commandes disponibles :
  help            Affiche cette aide
  build           Build l'image Docker de l'application
  infra           Provisionne l'infrastructure avec Terraform
  configure       Configure la VM avec Ansible
  deploy          Déploie tout (infra + config) en une commande
  destroy         Détruit l'infrastructure Terraform
  clean           Nettoyage complet (destroy + Docker cleanup)
  status          Affiche le statut de l'infrastructure
  test            Teste l'application déployée
  validate        Valide la configuration (Terraform + Ansible)
  logs            Affiche les logs de l'application
```

---

### 🔨 Étape 3 : Build de l'image

```bash
make build
```

**Résultat attendu** :
```
🔨 Building application image...
[+] Building 2.3s (10/10) FINISHED
✅ Image built: devops-local-app:latest
```

---

### 🚀 Étape 4 : Déploiement complet

**Une seule commande pour tout déployer** :

```bash
make deploy
```

**Flux d'exécution** :
1. `build` : Création de l'image Docker
2. `infra` : Terraform provisionne l'infrastructure
3. `configure` : Ansible configure la VM
4. Message de succès

**Résultat attendu** :
```
🔨 Building application image...
✅ Image built
🚀 Provisioning infrastructure (workspace: dev)...
✅ Infrastructure provisioned
⚙️  Configuring VM with Ansible...
✅ Configuration applied
✅ Deployment complete!
Test with: make test
```

---

### 🔍 Étape 5 : Vérifier le statut

```bash
make status
```

**Résultat attendu** :
```
📊 Infrastructure Status

Docker containers:
NAMES                          STATUS          PORTS
devops-local-lab-nginx-dev     Up 2 minutes    0.0.0.0:8080->80/tcp
devops-local-lab-app-dev       Up 2 minutes    

Terraform workspace:
dev

Terraform resources:
docker_network.devops_net
docker_container.nginx
docker_container.app
local_file.ansible_inventory
```

---

### 🧪 Étape 6 : Tester l'application

```bash
make test
```

**Résultat attendu** :
```
🧪 Testing deployed application...
{
  "status": "ok"
}
✅ Health check passed
```

---

### 🏭 Étape 7 : Déployer en prod

```bash
make deploy WORKSPACE=prod
```

**Différences avec dev** :
- Workspace Terraform : `prod`
- Port Nginx : 80 (au lieu de 8080)
- Conteneurs suffixés `-prod`

---

### ✅ Étape 8 : Valider la configuration

```bash
make validate
```

**Résultat attendu** :
```
🔍 Validating Terraform...
Success! The configuration is valid.
🔍 Validating Ansible...
playbook: site.yml
✅ Validation passed
```

---

### 📋 Étape 9 : Voir les logs

```bash
make logs
```

**Résultat attendu** : Flux de logs en temps réel de l'application.

---

### 🗑️ Étape 10 : Nettoyer

**Détruire l'infrastructure** :
```bash
make destroy
```

**Nettoyage complet (+ cleanup Docker)** :
```bash
make clean
```

---

## ✅ Critères de réussite

### Structure
- [ ] `Makefile` existe à la racine du projet
- [ ] Contient au moins 10 targets (help, build, infra, configure, deploy, destroy, clean, status, test, validate)

### Fonctionnalités
- [ ] `make help` affiche toutes les commandes avec descriptions
- [ ] `make build` crée l'image Docker sans erreur
- [ ] `make infra` provisionne Terraform
- [ ] `make configure` exécute Ansible
- [ ] `make deploy` exécute tout le pipeline en une commande
- [ ] `make test` vérifie que l'app répond
- [ ] `make status` affiche l'état de l'infra
- [ ] `make destroy` nettoie proprement
- [ ] `make deploy WORKSPACE=prod` fonctionne

### Qualité
- [ ] Variables utilisées pour éviter la duplication
- [ ] Affichage coloré et émojis pour meilleure UX
- [ ] Gestion d'erreurs avec `||` et codes de retour
- [ ] `.PHONY` déclaré pour tous les targets virtuels
- [ ] **Utilisation de TABS (pas d'espaces) pour l'indentation des commandes**

---

## 💡 Points clés à retenir

1. **Make** : Outil universel d'orchestration
2. **Targets** : Commandes réutilisables (`make <target>`)
3. **Dépendances** : `deploy: infra configure` → chaînage automatique
4. **Variables** : `$(VARIABLE)` pour configuration flexible
5. **`.PHONY`** : Targets virtuels (pas de fichiers)
6. **`@`** : Masque la commande elle-même dans l'output
7. **`||`** : Gestion de fallback (si échec, exécute alternative)
8. **Pipeline IaC** : Build → Infra → Config → Deploy → Test

---

## 🚨 Pièges courants

### ❌ Utiliser des espaces au lieu de tabs
```makefile
# MAUVAIS : Espaces (erreur Make)
deploy:
    echo "Hello"
```

```makefile
# BON : Tabulation (TAB key)
deploy:
	echo "Hello"
```

**⚠️ CRITIQUE** : Make **exige des TAB**, pas des espaces !

---

### ❌ Oublier `.PHONY`
```makefile
# MAUVAIS : Si un fichier "deploy" existe, make ne fera rien
deploy:
	echo "Deploying..."
```

```makefile
# BON : Force l'exécution même si fichier existe
.PHONY: deploy
deploy:
	echo "Deploying..."
```

---

### ❌ Ne pas gérer les erreurs
```makefile
# MAUVAIS : Si workspace n'existe pas, tout échoue
deploy:
	terraform workspace select dev
```

```makefile
# BON : Crée le workspace si inexistant
deploy:
	terraform workspace select dev || terraform workspace new dev
```

---

### ❌ Chemins relatifs incorrects
```makefile
# MAUVAIS : Ne fonctionne que si on est à la racine
deploy:
	cd terraform && terraform apply
```

```makefile
# BON : Utilise une variable
TERRAFORM_DIR = infra/terraform
deploy:
	cd $(TERRAFORM_DIR) && terraform apply
```

---

## 🎨 Bonus : Targets avancées

### CI Pipeline complet
```makefile
ci: ## Simule un pipeline CI/CD complet
	@echo "$(BLUE)🔄 Running CI pipeline...$(NC)"
	make validate
	make build
	make deploy WORKSPACE=ci
	make test
	make destroy WORKSPACE=ci
	@echo "$(GREEN)✅ CI pipeline complete$(NC)"
```

### Backup du state Terraform
```makefile
backup: ## Sauvegarde le state Terraform
	@mkdir -p backups
	@cd $(TERRAFORM_DIR) && \
		terraform state pull > ../../backups/terraform-$(WORKSPACE)-$(shell date +%Y%m%d-%H%M%S).tfstate
	@echo "$(GREEN)✅ State backed up$(NC)"
```

### Watch logs
```makefile
watch-logs: ## Surveille les logs en temps réel
	watch -n 2 'docker logs --tail 20 devops-local-lab-app-dev 2>/dev/null'
```

---

## 🔗 Workflow recommandé

### Développement quotidien
```bash
# Déployer
make deploy

# Tester
make test

# Voir les logs
make logs

# Nettoyer
make destroy
```

### Avant un commit
```bash
make validate  # Vérifie Terraform + Ansible
```

### CI/CD
```bash
make ci  # Pipeline complet en environnement isolé
```

---

## 📊 Comparaison avant/après Make

### ❌ Sans Make (manuel, 7 commandes)
```bash
docker build -t devops-local-app:latest app/
cd infra/terraform
terraform workspace select dev || terraform workspace new dev
terraform init -upgrade
terraform apply -auto-approve
cd ../ansible
ansible-playbook -i inventory.ini site.yml
```

### ✅ Avec Make (automatisé, 1 commande)
```bash
make deploy
```

**Gain** : 85% de commandes en moins, réutilisable, documenté !

---

## 🔗 Intégration Git hooks

Créez `.git/hooks/pre-push` :

```bash
#!/bin/bash
echo "Running pre-push checks..."
make validate || exit 1
echo "✅ Validation passed, pushing..."
```

Rendez-le exécutable :
```bash
chmod +x .git/hooks/pre-push
```

---

## 🎓 Concepts IaC validés

- ✅ **Infrastructure as Code** : Toute l'infra en code versionné
- ✅ **Automation** : Pipeline complet en une commande
- ✅ **Idempotence** : Relancer `make deploy` = sûr
- ✅ **Reproductibilité** : Mêmes commandes, même résultat
- ✅ **Documentation** : `make help` = documentation vivante

---

## 📚 Ressources complémentaires
- [GNU Make Manual](https://www.gnu.org/software/make/manual/)
- [Makefile Tutorial](https://makefiletutorial.com/)
- [Best Practices for Makefiles](https://tech.davis-hansson.com/p/make/)
- [Shell Colors in Make](https://misc.flogisoft.com/bash/tip_colors_and_formatting)
