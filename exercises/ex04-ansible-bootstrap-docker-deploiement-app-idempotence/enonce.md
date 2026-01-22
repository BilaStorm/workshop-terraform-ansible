# Ex04 — Ansible : Bootstrap + Docker + Déploiement app (idempotence)

## 🎯 Objectif pédagogique
Apprendre à **utiliser Ansible pour configurer des serveurs** en créant votre premier playbook et vos premiers rôles.

**Concepts couverts** :
- **Playbooks** : Fichiers décrivant les tâches Ansible
- **Rôles** : Organisation modulaire des tâches
- **Modules Ansible** : Actions atomiques (apt, file, template, etc.)
- **Idempotence** : Ré-exécuter N fois = même résultat
- **Handlers** : Actions déclenchées uniquement si changement

Vous allez créer 3 rôles pour installer Docker et déployer l'application.

---

## 📋 Prérequis
- Avoir complété Ex01, Ex02 et Ex03
- Disposer d'un inventory Ansible (`infra/ansible/inventory.ini`)
- Avoir Terraform déployé (conteneurs + réseau)

**Note** : Pour cet exercice, nous allons **simuler** la configuration d'une VM. Dans un scénario réel, vous auriez un conteneur avec SSH actif. Ici, nous allons créer les fichiers Ansible et comprendre leur structure.

---

## 🎓 Concepts théoriques

### Qu'est-ce qu'Ansible ?
**Ansible** est un outil d'**automatisation de configuration** :
- **Agentless** : Pas d'agent à installer, utilise SSH
- **Déclaratif** : Vous déclarez l'état souhaité, Ansible le réalise
- **Idempotent** : Exécuter plusieurs fois = même résultat

**Exemple** : "Je veux que Docker soit installé"
- Si Docker est absent → Ansible l'installe
- Si Docker est déjà là → Ansible ne fait rien

### Architecture Ansible

```
Playbook (site.yml)
    ↓
  Rôles (bootstrap, docker, app)
    ↓
  Tasks (tâches individuelles)
    ↓
  Modules (apt, file, template...)
```

### Playbook vs Rôle

| Concept | Description | Exemple |
|---------|-------------|---------|
| **Playbook** | Fichier principal qui orchestre les rôles | `site.yml` |
| **Rôle** | Ensemble de tâches pour une fonction précise | `docker`, `nginx` |
| **Task** | Action atomique | "Installer le package curl" |
| **Module** | Commande Ansible prédéfinie | `apt`, `file`, `template` |

### Idempotence : Le concept clé

**Définition** : Une opération est **idempotente** si l'exécuter plusieurs fois produit le même résultat qu'une seule fois.

**Exemple idempotent** :
```yaml
- name: Install curl
  apt:
    name: curl
    state: present
```
- 1ère exécution : `curl` absent → **installé** (changed)
- 2ème exécution : `curl` déjà présent → **aucune action** (ok)

**Exemple NON idempotent** :
```yaml
- name: Download file
  shell: wget http://example.com/file.txt
```
- À chaque exécution : **téléchargement** même si le fichier existe déjà !

**💡 Règle d'or** : Toujours utiliser les **modules Ansible** plutôt que `shell` ou `command`.

---

## 📝 Énoncé pas à pas

### 📁 Étape 1 : Créer la structure des rôles

Ansible s'attend à une structure de dossiers spécifique pour les rôles.

**Créez la structure** :
```bash
cd infra/ansible
mkdir -p roles/bootstrap/tasks
mkdir -p roles/docker/tasks
mkdir -p roles/app/{tasks,templates,handlers}
```

**Structure finale** :
```
infra/ansible/
├── ansible.cfg
├── inventory.ini
├── site.yml          # 👈 À créer (playbook principal)
└── roles/
    ├── bootstrap/
    │   └── tasks/
    │       └── main.yml
    ├── docker/
    │   └── tasks/
    │       └── main.yml
    └── app/
        ├── tasks/
        │   └── main.yml
        ├── templates/
        │   └── docker-compose.yml.j2
        └── handlers/
            └── main.yml
```

---

### 📄 Étape 2 : Créer le rôle `bootstrap`

Ce rôle prépare la machine en installant les dépendances de base.

**Créez `roles/bootstrap/tasks/main.yml`** :

```yaml
---
# Rôle : bootstrap
# Objectif : Préparer la machine avec les packages essentiels

- name: Update apt cache
  ansible.builtin.apt:
    update_cache: yes
    cache_valid_time: 3600
  tags: bootstrap

- name: Install basic packages
  ansible.builtin.apt:
    name:
      - curl
      - git
      - python3-pip
      - vim
    state: present
  tags: bootstrap
```

**💡 Explication ligne par ligne** :
- `---` : Début d'un document YAML
- `- name: "..."` : Description humaine de la tâche (apparaît dans les logs)
- `ansible.builtin.apt` : Module Ansible pour gérer les packages APT (Debian/Ubuntu)
  - Collection `builtin` (intégrée, pas besoin d'installer)
- `update_cache: yes` : Équivalent de `apt-get update`
- `cache_valid_time: 3600` : Ne met à jour que si le cache a + de 1h (idempotence)
- `name: [...]` : Liste de packages à installer
- `state: present` : "Je veux que ces packages soient installés"
  - Si absents → installation
  - Si présents → aucune action
- `tags: bootstrap` : Permet d'exécuter uniquement ce rôle (`ansible-playbook --tags bootstrap`)

---

### 🐳 Étape 3 : Créer le rôle `docker`

Ce rôle installe Docker et Docker Compose.

**Créez `roles/docker/tasks/main.yml`** :

```yaml
---
# Rôle : docker
# Objectif : Installer Docker et Docker Compose

- name: Install Docker dependencies
  ansible.builtin.apt:
    name:
      - apt-transport-https
      - ca-certificates
      - gnupg
      - lsb-release
    state: present
  tags: docker

- name: Create directory for Docker GPG key
  ansible.builtin.file:
    path: /etc/apt/keyrings
    state: directory
    mode: '0755'
  tags: docker

- name: Add Docker GPG key
  ansible.builtin.apt_key:
    url: https://download.docker.com/linux/ubuntu/gpg
    state: present
  tags: docker

- name: Add Docker repository
  ansible.builtin.apt_repository:
    repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
    state: present
  tags: docker

- name: Install Docker
  ansible.builtin.apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
    state: present
    update_cache: yes
  tags: docker

- name: Install Docker Compose via pip
  ansible.builtin.pip:
    name: docker-compose
    state: present
  tags: docker

- name: Ensure Docker service is started and enabled
  ansible.builtin.systemd:
    name: docker
    state: started
    enabled: yes
  tags: docker

- name: Add ansible user to docker group
  ansible.builtin.user:
    name: ansible
    groups: docker
    append: yes
  tags: docker
```

**💡 Nouveaux modules** :
- `ansible.builtin.file` : Créer/supprimer des fichiers et dossiers
  - `state: directory` : Créer un dossier
  - `mode: '0755'` : Permissions (rwxr-xr-x)
- `ansible.builtin.apt_key` : Gérer les clés GPG pour APT
- `ansible.builtin.apt_repository` : Ajouter des dépôts APT
- `ansible.builtin.pip` : Installer des packages Python
- `ansible.builtin.systemd` : Gérer les services systemd
  - `state: started` : Démarrer le service
  - `enabled: yes` : Démarrer automatiquement au boot
- `ansible.builtin.user` : Gérer les utilisateurs
  - `groups: docker` : Ajouter au groupe docker
  - `append: yes` : Ajouter sans supprimer les autres groupes

---

### 📦 Étape 4 : Créer le rôle `app`

Ce rôle déploie l'application Flask via Docker Compose.

**4a) Créez `roles/app/tasks/main.yml`** :

```yaml
---
# Rôle : app
# Objectif : Déployer l'application Flask avec Docker Compose

- name: Create application directory
  ansible.builtin.file:
    path: /opt/devops-lab-app
    state: directory
    mode: '0755'
    owner: ansible
    group: ansible
  tags: app

- name: Deploy docker-compose.yml from template
  ansible.builtin.template:
    src: docker-compose.yml.j2
    dest: /opt/devops-lab-app/docker-compose.yml
    mode: '0644'
    owner: ansible
    group: ansible
  tags: app
  notify: Restart app containers

- name: Start application with Docker Compose
  community.docker.docker_compose:
    project_src: /opt/devops-lab-app
    state: present
  tags: app
```

**💡 Nouveaux concepts** :
- `ansible.builtin.template` : Copie un fichier en remplaçant les variables
  - `src: docker-compose.yml.j2` : Template Jinja2 (dans `roles/app/templates/`)
  - `dest: /opt/...` : Destination sur la cible
- `notify: Restart app containers` : Déclenche un **handler** (uniquement si changement)
- `community.docker.docker_compose` : Module pour gérer Docker Compose
  - Collection externe : `community.docker`
  - `project_src` : Dossier contenant `docker-compose.yml`
  - `state: present` : Démarrer les conteneurs

---

**4b) Créez le template `roles/app/templates/docker-compose.yml.j2`** :

```yaml
# docker-compose.yml.j2
# Template Jinja2 pour générer docker-compose.yml

version: '3.8'

services:
  flask_app:
    image: devops-local-app:latest
    container_name: devops_lab_flask_app
    ports:
      - "5000:5000"
    environment:
      - FLASK_ENV=production
      - PORT=5000
    restart: unless-stopped
```

**💡 Explication** :
- Extension `.j2` : Format Jinja2 (moteur de templates Python)
- `{{ variable }}` : Permet d'injecter des variables Ansible (ici aucune, mais on pourrait)
- Ansible copiera ce fichier sur la cible en le rendant

---

**4c) Créez le handler `roles/app/handlers/main.yml`** :

```yaml
---
# Handlers : Actions déclenchées par notify

- name: Restart app containers
  community.docker.docker_compose:
    project_src: /opt/devops-lab-app
    state: restarted
  listen: "Restart app containers"
```

**💡 Concept : Handlers** :
- Un **handler** est une tâche spéciale, exécutée **uniquement si déclenchée** par `notify`
- Déclenchement : Quand une tâche **change quelque chose**
- Utile pour : Redémarrer des services après modification de config

**Exemple de flux** :
1. Tâche "Deploy docker-compose.yml" → **changed** (fichier modifié)
2. → Déclenche `notify: Restart app containers`
3. → Handler exécuté **en fin de playbook**

Si le fichier n'a pas changé → Pas de `changed` → Handler pas exécuté !

---

### 🎭 Étape 5 : Créer le playbook principal

Le playbook orchestre l'exécution des rôles.

**Créez `infra/ansible/site.yml`** :

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
```

**💡 Explication** :
- `hosts: vm` : Cible le groupe `[vm]` de l'inventory
- `become: yes` : Élève les privilèges (sudo) pour toutes les tâches
- `gather_facts: yes` : Collecte des infos sur la cible (OS, IP, etc.)
  - Crée des variables comme `ansible_distribution_release`
- `roles: [...]` : Liste des rôles à exécuter, dans l'ordre

---

### 🚀 Étape 6 : Vérifier la syntaxe

Avant d'exécuter, validez la syntaxe :

```bash
cd infra/ansible
ansible-playbook site.yml --syntax-check
```

**Résultat attendu** :
```
playbook: site.yml
```

---

### 🔥 Étape 7 : Exécuter le playbook (dry-run)

Le mode **check** (`--check`) simule l'exécution sans rien modifier :

```bash
ansible-playbook -i inventory.ini site.yml --check
```

**💡 Interprétation** :
- Les tâches marquées **changed** : Ce qui serait modifié
- Les tâches marquées **ok** : Déjà dans l'état souhaité
- **Skipped** : Tâches ignorées (conditions non remplies)

**Note** : Certains modules ne supportent pas `--check` (ex: `docker_compose`). C'est normal.

---

### 🎯 Étape 8 : Exécuter le playbook (réellement)

**⚠️ Important** : Cette étape nécessite une vraie VM avec SSH. Dans le cadre de cet exercice pédagogique, nous **n'exécutons pas réellement**, mais voici la commande :

```bash
ansible-playbook -i inventory.ini site.yml
```

**Résultat attendu (simulation)** :
```
PLAY [Configure VM and deploy application] ************************

TASK [Gathering Facts] ********************************************
ok: [127.0.0.1]

TASK [bootstrap : Update apt cache] *******************************
changed: [127.0.0.1]

TASK [bootstrap : Install basic packages] *************************
changed: [127.0.0.1]

TASK [docker : Install Docker dependencies] ***********************
changed: [127.0.0.1]

[... autres tâches ...]

PLAY RECAP ********************************************************
127.0.0.1  ok=15  changed=12  unreachable=0  failed=0  skipped=0
```

**💡 Analyse** :
- `ok=15` : 15 tâches exécutées avec succès
- `changed=12` : 12 tâches ont modifié quelque chose
- `unreachable=0` : Toutes les cibles étaient joignables
- `failed=0` : Aucune erreur

---

### 🔁 Étape 9 : Prouver l'idempotence

Ré-exécutez le playbook **sans rien changer** :

```bash
ansible-playbook -i inventory.ini site.yml
```

**Résultat attendu (simulation)** :
```
PLAY RECAP ********************************************************
127.0.0.1  ok=15  changed=0  unreachable=0  failed=0  skipped=0
```

**💡 Analyse** :
- `changed=0` : **Aucune modification** !
- Preuve d'**idempotence** : Ansible détecte que l'état est déjà conforme

---

## ✅ Critères de réussite

### Structure des fichiers
- [ ] `infra/ansible/site.yml` existe (playbook principal)
- [ ] `infra/ansible/roles/bootstrap/tasks/main.yml` existe
- [ ] `infra/ansible/roles/docker/tasks/main.yml` existe
- [ ] `infra/ansible/roles/app/tasks/main.yml` existe
- [ ] `infra/ansible/roles/app/templates/docker-compose.yml.j2` existe
- [ ] `infra/ansible/roles/app/handlers/main.yml` existe

### Syntaxe
- [ ] `ansible-playbook site.yml --syntax-check` réussit sans erreur
- [ ] Tous les fichiers YAML sont valides (indentation à 2 espaces)

### Compréhension
- [ ] Vous savez expliquer la différence entre un **playbook** et un **rôle**
- [ ] Vous comprenez ce qu'est l'**idempotence** et pourquoi c'est important
- [ ] Vous savez ce qu'est un **handler** et quand il est exécuté

### Modules utilisés
- [ ] Aucun module `shell` ou `command` (sauf si absolument nécessaire)
- [ ] Utilisation des modules : `apt`, `file`, `template`, `systemd`, `user`, `pip`

---

## 💡 Points clés à retenir

1. **Idempotence** : Exécuter N fois = même résultat qu'une fois
2. **Modules > Shell** : Toujours préférer les modules Ansible aux commandes shell
3. **Rôles** : Organisation modulaire des tâches (réutilisables)
4. **Handlers** : Actions déclenchées uniquement si changement (ex: redémarrage)
5. **`become: yes`** : Élévation de privilèges (sudo)
6. **Tags** : Permettent d'exécuter seulement certaines parties (`--tags docker`)
7. **Templates Jinja2** : Génération de fichiers dynamiques avec variables

---

## 🚨 Pièges courants

### ❌ Oublier `become: yes`
```yaml
# MAUVAIS : Permission denied sur /opt
- name: Create directory
  file:
    path: /opt/app
    state: directory
```

```yaml
# BON : Avec élévation de privilèges
- name: Create directory
  file:
    path: /opt/app
    state: directory
  become: yes
```

### ❌ Utiliser `command` au lieu de modules
```yaml
# MAUVAIS : Pas idempotent
- name: Install curl
  command: apt-get install -y curl
```

```yaml
# BON : Idempotent
- name: Install curl
  apt:
    name: curl
    state: present
```

### ❌ Indentation YAML incorrecte
```yaml
# MAUVAIS : Indentation mixte (espaces + tabs)
- name: Task
	apt:
	  name: curl
```

```yaml
# BON : Indentation à 2 espaces
- name: Task
  apt:
    name: curl
```

### ❌ Oublier d'installer la collection `community.docker`
```bash
# Si erreur "module community.docker.docker_compose not found"
ansible-galaxy collection install community.docker
```

---

## 🔗 Étapes suivantes
➡️ [Ex05 : Nginx reverse proxy + handlers](../ex05-ansible-nginx-reverse-proxy-handlers/enonce.md)

---

## 📚 Ressources complémentaires
- [Ansible Documentation - Modules](https://docs.ansible.com/ansible/latest/collections/index_module.html)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
- [Idempotence Explained](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html#term-Idempotency)
- [Jinja2 Templates](https://docs.ansible.com/ansible/latest/user_guide/playbooks_templating.html)
- [Ansible Handlers](https://docs.ansible.com/ansible/latest/user_guide/playbooks_handlers.html)
