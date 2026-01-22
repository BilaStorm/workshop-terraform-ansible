# 🏗️ Dossier Infrastructure (Workspace)

Ce dossier est votre **espace de travail** pour construire l'infrastructure du workshop.

## 📁 Structure à créer

Au fil des exercices, vous allez construire progressivement :

```
infra/
├── terraform/           ← Ex01-Ex03 : Provisionning
│   ├── versions.tf     ← Ex01 : Versions Terraform et providers
│   ├── providers.tf    ← Ex01 : Configuration Docker provider
│   ├── variables.tf    ← Ex02 : Variables et configuration
│   ├── main.tf         ← Ex01-Ex03 : Ressources principales
│   ├── outputs.tf      ← Ex03 : Outputs Terraform
│   └── generated/      ← Ex03 : Fichiers générés (inventory, configs)
│
└── ansible/            ← Ex03-Ex05 : Configuration
    ├── ansible.cfg     ← Ex03 : Configuration Ansible
    ├── inventory.ini   ← Ex03 : Généré par Terraform
    ├── site.yml        ← Ex04 : Playbook principal
    └── roles/          ← Ex04-Ex05 : Rôles de configuration
        ├── bootstrap/
        ├── docker/
        ├── app/
        └── nginx/
```

## 🚀 Démarrage

**Ne créez RIEN maintenant !** Suivez les exercices dans l'ordre :

1. **[Ex01](../exercises/ex01-terraform-hello-infra-plan-apply-destroy/)** : Premier fichier Terraform
2. **[Ex02](../exercises/ex02-terraform-variables-workspaces-dev-prod/)** : Variables et multi-environnements
3. **[Ex03](../exercises/ex03-terraform-ansible-generer-inventory-ini-automatiquement/)** : Génération d'inventory
4. **[Ex04](../exercises/ex04-ansible-bootstrap-docker-deploiement-app-idempotence/)** : Rôles Ansible
5. **[Ex05](../exercises/ex05-ansible-nginx-reverse-proxy-handlers/)** : Nginx et handlers
6. **[Ex06](../exercises/ex06-chainage-makefile-mini-ci-cd-local/)** : Makefile pipeline

