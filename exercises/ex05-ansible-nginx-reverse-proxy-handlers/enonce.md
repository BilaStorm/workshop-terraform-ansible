# Ex05 — Ansible : Nginx reverse proxy + handlers

## 🎯 Objectif pédagogique
Apprendre à **configurer un reverse proxy Nginx** avec Ansible et maîtriser les **handlers** pour gérer les redémarrages de services.

**Concepts couverts** :
- **Reverse proxy** : Servir l'application Flask via Nginx
- **Handlers Ansible** : Actions déclenchées uniquement si changement
- **Templates avancés** : Configuration Nginx dynamique
- **Gestion de services** : reload vs restart

---

## 📋 Prérequis
- Avoir complété Ex01 à Ex04
- Comprendre les rôles Ansible et les playbooks
- Disposer des rôles `bootstrap`, `docker` et `app`

---

## 🎓 Concepts théoriques

### Qu'est-ce qu'un Reverse Proxy ?

Un **reverse proxy** est un serveur intermédiaire qui :
- **Reçoit** les requêtes HTTP des clients
- **Transmet** ces requêtes à l'application backend
- **Retourne** la réponse au client

**Avantages** :
- Point d'entrée unique (port 80/443)
- Gestion SSL/TLS centralisée
- Cache statique (images, CSS, JS)
- Load balancing (répartition de charge)
- Headers HTTP normalisés

**Flux** :
```
Client → Nginx (port 80) → Flask (port 5000) → Nginx → Client
```

---

### Handlers : Actions conditionnelles

Les **handlers** sont des tâches spéciales exécutées **uniquement si déclenchées** par `notify`.

**Caractéristiques** :
- Déclenchement : Quand une tâche a `changed: true`
- Exécution : **En fin de playbook** (pas immédiatement)
- Unicité : Même si appelé plusieurs fois, exécuté **une seule fois**

**Exemple** :
```yaml
- name: Deploy config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx  # 👈 Déclenche le handler
```

Si le fichier change → Handler exécuté  
Si le fichier est identique → Handler **ignoré**

---

### Reload vs Restart

| Action | Comportement | Downtime | Usage |
|--------|-------------|----------|-------|
| **reload** | Recharge la config sans couper les connexions | ❌ Non | Changement de config |
| **restart** | Arrête puis redémarre le service | ✅ Oui | Problème grave, mise à jour binaire |

**💡 Règle** : Toujours préférer `reload` pour Nginx (graceful).

---

## 📝 Énoncé pas à pas

### 📁 Étape 1 : Créer la structure du rôle nginx

```bash
cd infra/ansible
mkdir -p roles/nginx/{tasks,templates,handlers}
```

**Structure finale** :
```
roles/nginx/
├── tasks/
│   └── main.yml
├── templates/
│   └── default.conf.j2
└── handlers/
    └── main.yml
```

---

### 📄 Étape 2 : Créer les tâches du rôle nginx

**Créez `roles/nginx/tasks/main.yml`** :

```yaml
---
# Rôle : nginx
# Objectif : Installer et configurer Nginx comme reverse proxy

- name: Install Nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: yes
  tags: nginx

- name: Ensure Nginx is started and enabled
  ansible.builtin.systemd:
    name: nginx
    state: started
    enabled: yes
  tags: nginx

- name: Deploy Nginx configuration for Flask app
  ansible.builtin.template:
    src: default.conf.j2
    dest: /etc/nginx/sites-available/default
    mode: '0644'
  tags: nginx
  notify: Reload Nginx

- name: Remove default Nginx welcome page
  ansible.builtin.file:
    path: /var/www/html/index.nginx-debian.html
    state: absent
  tags: nginx
```

**💡 Explication** :
- `Install Nginx` : Installation du package
- `Ensure Nginx is started` : Service démarré et activé au boot
- `Deploy Nginx configuration` : Copie le template avec `notify`
  - Si le fichier change → Handler `Reload Nginx` déclenché
  - Si identique → Handler ignoré
- `Remove default page` : Supprime la page "Welcome to nginx!"

---

### 📐 Étape 3 : Créer le template de configuration Nginx

**Créez `roles/nginx/templates/default.conf.j2`** :

```nginx
# Configuration Nginx pour reverse proxy Flask
# Généré automatiquement par Ansible

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    
    server_name _;

    # Logs
    access_log /var/log/nginx/flask_access.log;
    error_log /var/log/nginx/flask_error.log;

    # Reverse proxy vers l'application Flask
    location / {
        proxy_pass http://flask_app:5000;
        proxy_http_version 1.1;
        
        # Headers pour préserver les informations client
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint (sans logs)
    location /health {
        proxy_pass http://flask_app:5000/health;
        access_log off;
    }

    # Gestion des erreurs
    error_page 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

**💡 Explication** :
- `listen 80` : Écoute sur port 80 (HTTP standard)
- `server_name _` : Wildcard (accepte tous les noms de domaine)
- `proxy_pass http://flask_app:5000` : 
  - `flask_app` = nom du conteneur Docker
  - Docker résout ce nom via DNS interne
- **Headers proxy** : Préservent l'IP client originale et le protocole
- `access_log off` pour `/health` : Évite de polluer les logs
- `error_page 502 503 504` : Gestion des erreurs backend

---

### 🔔 Étape 4 : Créer les handlers

**Créez `roles/nginx/handlers/main.yml`** :

```yaml
---
# Handlers : Actions déclenchées par notify

- name: Reload Nginx
  ansible.builtin.systemd:
    name: nginx
    state: reloaded
  listen: "Reload Nginx"

- name: Restart Nginx
  ansible.builtin.systemd:
    name: nginx
    state: restarted
  listen: "Restart Nginx"
```

**💡 Explication** :
- `Reload Nginx` : Recharge la config sans coupure (graceful)
- `Restart Nginx` : Redémarrage complet (à éviter en prod)
- `listen: "..."` : Nom écouté par `notify`

---

### 🎭 Étape 5 : Ajouter le rôle nginx au playbook

**Modifiez `infra/ansible/site.yml`** :

```yaml
---
# Playbook principal : Configuration complète de la VM

- name: Configure VM and deploy application
  hosts: vm
  become: yes
  gather_facts: yes
  
  roles:
    - bootstrap
    - docker
    - app
    - nginx  # 👈 AJOUT du rôle nginx
```

---

### 🚀 Étape 6 : Exécuter le playbook

```bash
cd infra/ansible
ansible-playbook -i inventory.ini site.yml --tags nginx
```

**💡 Note** : `--tags nginx` exécute uniquement les tâches du rôle nginx.

**Résultat attendu (simulation)** :
```
TASK [nginx : Install Nginx] **********************************
changed: [127.0.0.1]

TASK [nginx : Ensure Nginx is started and enabled] ************
ok: [127.0.0.1]

TASK [nginx : Deploy Nginx configuration for Flask app] *******
changed: [127.0.0.1]

RUNNING HANDLER [nginx : Reload Nginx] ************************
changed: [127.0.0.1]
```

**💡 Analyse** :
- Handler `Reload Nginx` déclenché car config déployée (changed)

---

### 🔁 Étape 7 : Prouver l'idempotence des handlers

**Ré-exécutez le playbook** :
```bash
ansible-playbook -i inventory.ini site.yml --tags nginx
```

**Résultat attendu** :
```
TASK [nginx : Deploy Nginx configuration for Flask app] *******
ok: [127.0.0.1]  # 👈 ok, pas changed !

# Aucun handler exécuté
```

**💡 Concept validé** : Config identique → Pas de changement → Handler **non exécuté**.

---

### 🧪 Étape 8 : Tester le reverse proxy

**Test 1 : Endpoint racine** :
```bash
curl http://localhost:80/
```

**Résultat attendu** : Réponse de l'app Flask.

**Test 2 : Health check** :
```bash
curl http://localhost:80/health
```

**Résultat attendu** : `{"status":"ok"}`

---

### 🔧 Étape 9 : Forcer un redéploiement (test du handler)

**Modifiez le template** (ajoutez un commentaire) :
```nginx
# Mise à jour du {{ansible_date_time.date}}
server {
    ...
}
```

**Ré-exécutez** :
```bash
ansible-playbook -i inventory.ini site.yml --tags nginx
```

**Résultat attendu** :
```
TASK [nginx : Deploy Nginx configuration for Flask app] *******
changed: [127.0.0.1]  # 👈 Fichier modifié

RUNNING HANDLER [nginx : Reload Nginx] ************************
changed: [127.0.0.1]  # 👈 Handler déclenché
```

---

## ✅ Critères de réussite

### Structure des fichiers
- [ ] `infra/ansible/roles/nginx/tasks/main.yml` existe
- [ ] `infra/ansible/roles/nginx/templates/default.conf.j2` existe
- [ ] `infra/ansible/roles/nginx/handlers/main.yml` existe
- [ ] Le rôle `nginx` est ajouté dans `site.yml`

### Syntaxe
- [ ] `ansible-playbook site.yml --syntax-check` réussit
- [ ] La config Nginx est valide (syntaxe nginx correcte)

### Handlers
- [ ] 1ère exécution : Handler `Reload Nginx` déclenché
- [ ] 2ème exécution (sans changement) : Handler **non déclenché**
- [ ] Modification du template : Handler **déclenché**

### Compréhension
- [ ] Vous savez expliquer la différence entre `reload` et `restart`
- [ ] Vous comprenez quand un handler est exécuté
- [ ] Vous savez pourquoi utiliser un reverse proxy

---

## 💡 Points clés à retenir

1. **Reverse proxy** : Point d'entrée unique, gestion SSL, cache
2. **Handlers** : Exécutés uniquement si changement (`changed: true`)
3. **`reload` > `restart`** : Pas de downtime avec reload
4. **Headers proxy** : Préservent l'IP client (`X-Real-IP`, `X-Forwarded-For`)
5. **`notify`** : Peut être appelé N fois, handler exécuté **1 seule fois**
6. **Templates `.j2`** : Génération dynamique de configs

---

## 🚨 Pièges courants

### ❌ Oublier `notify`
```yaml
# MAUVAIS : Config déployée mais jamais appliquée
- name: Deploy config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
```

```yaml
# BON : Handler déclenché si changement
- name: Deploy config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: Reload Nginx
```

### ❌ Utiliser `restart` au lieu de `reload`
```yaml
# MAUVAIS : Downtime inutile
- name: Restart Nginx
  systemd:
    name: nginx
    state: restarted
```

```yaml
# BON : Graceful reload
- name: Reload Nginx
  systemd:
    name: nginx
    state: reloaded
```

### ❌ Proxy vers localhost au lieu du nom de conteneur
```nginx
# MAUVAIS : Ne fonctionne pas en Docker
proxy_pass http://localhost:5000;
```

```nginx
# BON : Résolution DNS Docker
proxy_pass http://flask_app:5000;
```

---

## 🔗 Étapes suivantes
➡️ [Ex06 : Chaînage Makefile (mini CI/CD local)](../ex06-chainage-makefile-mini-ci-cd-local/enonce.md)

---

## 📚 Ressources complémentaires
- [Ansible Handlers](https://docs.ansible.com/ansible/latest/user_guide/playbooks_handlers.html)
- [Nginx Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
- [Nginx Reload vs Restart](https://www.nginx.com/resources/wiki/start/topics/tutorials/commandline/)
- [Proxy Headers Explained](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/X-Forwarded-For)
