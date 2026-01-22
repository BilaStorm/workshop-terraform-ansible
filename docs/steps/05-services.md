# 7. Ansible : Nginx & Handlers

**Objectif** : Créer le rôle Ansible `nginx` pour configurer un reverse proxy et maîtriser les **handlers**.

## Contexte

Vous allez créer un nouveau rôle qui :
- Installe Nginx
- Déploie une configuration custom via template Jinja2
- Utilise un **handler** pour reload Nginx uniquement si la config change

## Concept : Handlers

Un **handler** est une tâche spéciale qui s'exécute **uniquement si déclenchée** par `notify` :
- Si config change → `notify: Reload Nginx` → Handler exécuté en fin de playbook
- Si config identique → Handler **ignoré**

Cela évite les redémarrages inutiles et respecte l'idempotence.

## Vue d'ensemble

Fichiers à créer :
1. **`roles/nginx/tasks/main.yml`** : Installation + déploiement config
2. **`roles/nginx/templates/default.conf.j2`** : Configuration Nginx pour reverse proxy
3. **`roles/nginx/handlers/main.yml`** : Handler pour reload Nginx
4. Modifier **`site.yml`** : Ajouter le rôle nginx

## Instructions détaillées

Suivez l'[exercice détaillé Ex05](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex05-ansible-nginx-reverse-proxy-handlers/enonce.md) qui explique :

1. **Création du rôle nginx** avec tâches d'installation
2. **Template Nginx** : Configuration reverse proxy avec headers (X-Real-IP, X-Forwarded-For)
3. **Handlers** : Différence entre `reload` (graceful) et `restart`
4. **Test d'idempotence** : Vérifier que le handler ne s'exécute que si nécessaire

## Instructions rapides

### 1. Créer la structure

```bash
cd infra/ansible
mkdir -p roles/nginx/{tasks,templates,handlers}
```

### 2. Créer les fichiers

- `roles/nginx/tasks/main.yml` : Installer nginx, déployer config, supprimer page par défaut
- `roles/nginx/templates/default.conf.j2` : Config reverse proxy vers `flask_app:5000`
- `roles/nginx/handlers/main.yml` : Handler "Reload Nginx" et "Restart Nginx"

### 3. Ajouter nginx au playbook

Modifiez `site.yml` pour inclure le rôle nginx après `app`.

### 4. Exécuter et tester

```bash
ansible-playbook -i inventory.ini site.yml --tags nginx
curl http://localhost:80/health  # Via Nginx
```

### 5. Vérifier l'idempotence du handler

Relancez le playbook : le handler ne doit **pas** s'exécuter.

Modifiez le template (ajoutez un commentaire), relancez : le handler **doit** s'exécuter.

> 📚 **Pour aller plus loin** : Consultez l'[exercice détaillé Ex05](https://github.com/othila-academy/workshop-terraform-ansible/tree/main/exercises/ex05-ansible-nginx-reverse-proxy-handlers/enonce.md) pour maîtriser les handlers et templates Jinja2.

