# 6. Ansible : Bootstrap & Déploiement App

**Objectif** : Créer vos premiers **rôles Ansible** from scratch (bootstrap, docker, app) et comprendre l'**idempotence**.

## Contexte

Vous allez créer la structure complète Ansible :
- **Rôles** : Modules réutilisables pour des fonctions spécifiques
- **Playbook** : Fichier orchestrant les rôles
- **Handlers** : Actions déclenchées uniquement si changement

## Vue d'ensemble

Fichiers à créer :
1. **`site.yml`** : Playbook principal
2. **Rôle `bootstrap`** : Installation packages de base (curl, git, python3-pip)
3. **Rôle `docker`** : Installation Docker + Docker Compose
4. **Rôle `app`** : Déploiement de l'application Flask

Chaque rôle contient :
- `tasks/main.yml` : Liste des tâches
- `templates/` : Templates Jinja2 (pour `app`)
- `handlers/main.yml` : Handlers (pour `app`)

## Instructions détaillées

Suivez l'[exercice détaillé Ex04](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex04-ansible-bootstrap-docker-deploiement-app-idempotence/enonce.md) qui explique :

1. **Création de la structure** des rôles (dossiers)
2. **Création de chaque fichier** avec explications ligne par ligne :
   - Modules Ansible (`apt`, `file`, `template`, `systemd`, `user`, `pip`)
   - Syntaxe YAML
   - Variables et tags
3. **Concept d'idempotence** : Pourquoi et comment

## Instructions rapides

### 1. Créer la structure

```bash
cd infra/ansible
mkdir -p roles/{bootstrap,docker,app}/{tasks,templates,handlers}
```

### 2. Créer les fichiers YAML

Pour chaque rôle, créez `tasks/main.yml` avec les tâches appropriées.

### 3. Créer le playbook

Créez `infra/ansible/site.yml` qui orchestre les 3 rôles.

### 4. Valider la syntaxe

```bash
ansible-playbook site.yml --syntax-check
```

### 5. Exécuter le playbook

```bash
ansible-playbook -i inventory.ini site.yml
```

Observez les tâches qui s'exécutent.

### 6. Vérifier l'idempotence

Relancez immédiatement :

```bash
ansible-playbook -i inventory.ini site.yml
```

Le `PLAY RECAP` doit afficher `changed=0` → Preuve d'idempotence !

***

## Critères de succès
- [ ] Le premier run Ansible termine sans erreur (`failed=0`).
- [ ] Le second run indique `changed=0`.

> 📚 **Pour aller plus loin** : Consultez l'[exercice détaillé Ex04](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex04-ansible-bootstrap-docker-deploiement-app-idempotence/enonce.md) avec exemples complets de rôles Ansible.
