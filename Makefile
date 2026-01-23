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