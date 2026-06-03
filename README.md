# Homelab — Self-hosted media & services stack

Stack Docker Compose complète, sécurisée et déployable en one-click sur un serveur Ubuntu/Debian vierge. Tous les secrets sont dans `.env` (jamais versionné). Les configurations sont versionnées et partageables publiquement.

---

Ma super mise à jour de contribution pour le README, avec une section détaillée sur les services inclus, l'architecture réseau, et un guide de déploiement étape par étape. J'ai aussi ajouté des sections sur la configuration manuelle, les disques supplémentaires, la mise à jour automatique, l'optimisation MKV, la sécurité, les commandes utiles et le dépannage.

## Services

| Service | Rôle | Port interne | README |
|---|---|---|---|
| **Nginx Proxy Manager** | Reverse proxy + TLS Let's Encrypt | 80/443 (admin :81 local) | [→](compose/nginx-proxy-manager/README.md) |
| **Plex** | Serveur média | 32400 (host) | [→](compose/plex/README.md) |
| **Tautulli** | Statistiques Plex | 8181 | [→](compose/tautulli/README.md) |
| **Radarr** | Gestion des films | 7878 | [→](compose/arr-stack/README.md) |
| **Sonarr** | Gestion des séries | 8989 | [→](compose/arr-stack/README.md) |
| **Seerr** | Demandes de médias | 5055 | [→](compose/arr-stack/README.md) |
| **Prowlarr** | Gestionnaire d'indexeurs | 9696 | [→](compose/torrenting/README.md) |
| **FlareSolverr** | Bypass Cloudflare | 8191 (interne) | [→](compose/arr-stack/README.md) |
| **RDTClient** | Client debrid (Real-Debrid, AllDebrid…) | 6500 | [→](compose/torrenting/README.md) |
| **Duplicati** | Sauvegardes chiffrées | 8200 | [→](compose/duplicati/README.md) |
| **ntfy** | Notifications push | 80 | [→](compose/ntfy.sh/README.md) |
| **Homepage** | Dashboard unifié | 3000 | [→](compose/homepage/README.md) |
| **Glances** | Monitoring système | 61208 | [→](compose/homepage/README.md) |
| **autoheal** | Redémarre les conteneurs `unhealthy` | — (interne) | — |

> **Résilience** : la plupart des services définissent un `healthcheck`. Le conteneur **autoheal** surveille tous ces healthchecks et **redémarre automatiquement** tout conteneur qui passe `unhealthy` (un `restart: unless-stopped` seul ne couvre pas un conteneur figé mais non crashé).

---

## Architecture réseau

Tous les conteneurs (sauf Plex) partagent le réseau Docker `proxy_manager`. La communication inter-service s'effectue directement par **nom de conteneur** sans exposer de ports sur l'hôte.

```
Internet
   │ 80/443
   ▼
Nginx Proxy Manager  (proxy_manager network)
   │
   ├── homepage:3000
   ├── radarr:7878      ──┐
   ├── sonarr:8989        ├─ arr-stack
   ├── seerr:5055         │
   ├── flaresolverr:8191 ─┘
   ├── prowlarr:9696  ─┐
   ├── rdtclient:6500  ├─ torrenting
   │                  ─┘
   ├── tautulli:8181
   ├── duplicati:8200
   ├── ntfy:80
   └── glances:61208

Plex (network_mode: host → port 32400 directement sur l'hôte)
   ▲
   └── Tautulli/Seerr atteignent Plex via host.docker.internal:32400
```

**Tableau des communications inter-conteneurs :**

| Depuis | Vers | URL à configurer |
|---|---|---|
| Radarr / Sonarr | RDTClient | `http://rdtclient:6500` |
| Radarr / Sonarr | Prowlarr | Sync auto via clé API |
| Prowlarr | FlareSolverr | `http://flaresolverr:8191` |
| Tautulli | Plex | `http://host.docker.internal:32400` |
| Seerr | Plex | `http://host.docker.internal:32400` |
| Seerr | Radarr | `http://radarr:7878` |
| Seerr | Sonarr | `http://sonarr:8989` |
| Homepage widgets | Tous | `http://<conteneur>:<port>` |

> `host.docker.internal` est automatiquement résolu vers l'IP de l'hôte grâce à `extra_hosts: host-gateway` configuré dans tautulli et seerr.

---

## Structure du repo

```
homelab/
├── .env.example                   # Template de toutes les variables (versionné)
├── .env                           # Valeurs réelles → .gitignore
├── .gitignore
├── .gitattributes
├── docker-compose.yml             # Compose racine (include: tous les sous-composes)
├── setup.sh                       # Script d'installation one-click
├── README.md
│
├── compose/
│   ├── arr-stack/                 # Radarr, Sonarr, Seerr, FlareSolverr
│   │   ├── docker-compose.yml
│   │   ├── radarr-config/         # Runtime → .gitignore
│   │   ├── sonarr-config/         # Runtime → .gitignore
│   │   └── seerr-config/          # Runtime → .gitignore
│   ├── duplicati/
│   ├── homepage/
│   │   ├── docker-compose.yml
│   │   └── config/                # YAML versionnés (secrets via {{VARIABLE}})
│   ├── nginx-proxy-manager/
│   │   ├── docker-compose.yml
│   │   ├── data/                  # Runtime → .gitignore
│   │   └── letsencrypt/           # Certificats → .gitignore
│   ├── ntfy.sh/
│   ├── plex/
│   ├── tautulli/
│   └── torrenting/                # Prowlarr, RDTClient
│
├── scripts/
│   ├── mkclean-bin                # Binaire ELF x86-64
│   ├── mkclean.sh                 # Script post-import Radarr/Sonarr
│   └── init-alpine.sh             # Inject gcompat dans conteneurs Alpine
│
└── updater/
    ├── updater.sh                 # Mise à jour images (--force-recreate)
    └── containers-to-update.conf  # Généré par setup.sh
```

---

## Prérequis

- Serveur **Ubuntu 22.04 / 24.04 LTS** ou **Debian 12** (x86-64)
- Accès root ou sudo
- **Nom de domaine** avec accès DNS (pour Let's Encrypt)
- **Ports 80 et 443** ouverts depuis Internet (NAT / firewall box — voir section 4)
- Optionnel : compte sur un service debrid ([Real-Debrid](https://real-debrid.com), [AllDebrid](https://alldebrid.com), etc.) pour RDTClient

---

## Déploiement sur un serveur vierge

### 1. Cloner le repo

```bash
# Remplacer l'URL par celle de ton fork / copie du repo
git clone https://github.com/ton-user/homelab.git /opt/homelab
cd /opt/homelab
```

### 2. Lancer setup.sh

```bash
sudo ./setup.sh
```

Le script interactif demande :

| Question | Par défaut | Description |
|---|---|---|
| Nom d'utilisateur système | `homelab` | User Linux créé et ajouté au groupe docker |
| Timezone | `Europe/Paris` | Utilisée par tous les conteneurs |
| Domaine | — | ex: `mondomaine.com` |
| IP LAN | `192.168.1.100` | IP locale du serveur |
| Répertoire médias | `/home/homelab/media` | Films, séries, animes |
| Répertoire downloads | `/home/homelab/downloads` | Téléchargements |
| Plex Claim token | — | Optionnel (obtenir sur plex.tv/claim) |
| Email NPM admin | `admin@<domaine>` | Compte admin Nginx Proxy Manager |

Les mots de passe (RDTClient, NPM) sont **générés automatiquement** et
sauvegardés dans le fichier **`.credentials`** (chmod 600, dans le répertoire du repo,
jamais versionné). Ils sont aussi affichés dans le terminal en fin d'exécution.

Ensuite `setup.sh` :
1. Installe Docker Engine + Compose plugin (Ubuntu **et** Debian)
2. Crée l'utilisateur système
3. Écrit `.env` et génère `.credentials` (mots de passe)
4. Crée les répertoires (`media/`, `downloads/`)
5. Crée le réseau Docker `proxy_manager`
6. Vérifie mkclean
7. Écrit `updater/containers-to-update.conf`
8. Démarre toutes les stacks
9. Configure le cron `/etc/cron.d/homelab-updater`

### 3. Configurer les DNS

Créer un enregistrement `A` par sous-domaine pointant vers l'IP publique du serveur :

```
home.yourdomain.com          → <IP_PUBLIQUE>
plex.yourdomain.com          → <IP_PUBLIQUE>
tv.yourdomain.com            → <IP_PUBLIQUE>
movies.yourdomain.com        → <IP_PUBLIQUE>
seer.yourdomain.com          → <IP_PUBLIQUE>
prowlarr.yourdomain.com      → <IP_PUBLIQUE>
rdt.yourdomain.com           → <IP_PUBLIQUE>
duplicati.yourdomain.com     → <IP_PUBLIQUE>
ntfy.yourdomain.com          → <IP_PUBLIQUE>
tautulli.yourdomain.com      → <IP_PUBLIQUE>
stats.yourdomain.com         → <IP_PUBLIQUE>
proxy-manager.yourdomain.com → <IP_PUBLIQUE>
```

> **Fournisseur DNS recommandé** : [Cloudflare](https://cloudflare.com) (gratuit, propagation rapide, compatible avec le DNS challenge Let's Encrypt de NPM).

### 4. Configurer le routeur / box internet

Pour que les services soient accessibles depuis l'extérieur (Internet), il faut configurer le routeur / box domestique.

#### 4.1 Redirection de ports (NAT / Port Forwarding)

Dans l'interface de ta box (ex: `192.168.1.1`) :

| Port externe | Port interne | Protocole | Cible |
|---|---|---|---|
| `80` | `80` | TCP | IP LAN du serveur (ex: `192.168.1.100`) |
| `443` | `443` | TCP | IP LAN du serveur |

> **Ne pas exposer le port 81** (interface NPM) — il est volontairement lié à `127.0.0.1` et accessible uniquement depuis le réseau local.

#### 4.2 Adresse IP fixe locale

Assigner une IP fixe (bail DHCP statique) au serveur dans la configuration DHCP de la box, pour que la redirection de ports reste valide après un redémarrage du serveur.

#### 4.3 IP publique dynamique (DDNS)

Si ton FAI attribue une IP publique dynamique (change à chaque reconnexion) :

**Option A — Cloudflare (recommandé) :**
1. Passer les DNS de ton domaine sur Cloudflare (gratuit)
2. Utiliser un client DDNS comme [`cloudflare-ddns`](https://github.com/favonia/cloudflare-ddns) en conteneur Docker pour mettre à jour automatiquement l'enregistrement A

**Option B — DuckDNS :**
1. Créer un sous-domaine gratuit sur [duckdns.org](https://www.duckdns.org)
2. Configurer un CNAME depuis ton domaine vers le sous-domaine DuckDNS
3. Lancer le client DuckDNS : `docker run -e SUBDOMAINS=monlab -e TOKEN=xxx ghcr.io/linuxserver/duckdns`

**Option C — No-IP / Dynu :**
Utiliser le client DDNS intégré à certaines box (Freebox, Livebox...) ou un client tiers.

#### 4.4 Test de connectivité

Avant de continuer :
```bash
# Vérifier que les ports 80 et 443 sont ouverts depuis l'extérieur
curl -s https://portchecker.co/check  # ou utiliser un outil en ligne
# Ou depuis une autre machine :
nmap -p 80,443 <IP_PUBLIQUE>
```

### 5. Configurer Nginx Proxy Manager

Accéder à **`http://<IP_SERVEUR>:81`** (depuis ton réseau local uniquement — port non exposé sur Internet).

**Première connexion :**
1. Email : `admin@example.com` / Mot de passe : `changeme` (identifiants par défaut NPM)
2. Une fois connecté : icône utilisateur en haut à droite → **Edit Profile**
3. Changer l'email pour : la valeur `Email` dans `.credentials`
4. Changer le mot de passe pour : la valeur `Mot de passe` dans `.credentials`
5. Sauvegarder → re-connexion avec les nouveaux identifiants

> `.credentials` se trouve à la racine du repo. Le `.env` est déjà configuré avec ces valeurs — rien d'autre à faire.

Pour chaque service : `Hosts → Proxy Hosts → Add Proxy Host`

| Domaine | Forward Hostname | Port | SSL |
|---|---|---|---|
| `home.domaine.com` | `homepage` | `3000` | ✅ |
| `plex.domaine.com` | `<IP_LAN_SERVEUR>` | `32400` | ✅ |
| `tv.domaine.com` | `sonarr` | `8989` | ✅ |
| `movies.domaine.com` | `radarr` | `7878` | ✅ |
| `seer.domaine.com` | `seerr` | `5055` | ✅ |
| `prowlarr.domaine.com` | `prowlarr` | `9696` | ✅ |
| `rdt.domaine.com` | `rdtclient` | `6500` | ✅ |
| `duplicati.domaine.com` | `duplicati` | `8200` | ✅ |
| `ntfy.domaine.com` | `ntfy` | `80` | ✅ |
| `tautulli.domaine.com` | `tautulli` | `8181` | ✅ |
| `stats.domaine.com` | `glances` | `61208` | ✅ |
| `proxy-manager.domaine.com` | `proxy-manager` | `81` | ✅ |

> SSL : `Request a new SSL Certificate` → cocher `Force SSL` + `HTTP/2 Support`

### 6. Configurer Plex

1. Aller sur `http://<IP_SERVEUR>:32400/web`
2. Ajouter les bibliothèques :
   - Films → `/media/movies`
   - Séries → `/media/tvseries`
   - Animes → `/media/animes`
3. Activer l'accès distant dans les paramètres

### 7. Configurer la stack arr

**Ordre :** Prowlarr → Radarr → Sonarr → RDTClient → Seerr

#### Prowlarr
1. `Paramètres → Apps → + Radarr` :
   - Prowlarr Server : `http://prowlarr:9696`
   - Radarr Server : `http://radarr:7878` + clé API Radarr
2. Même chose pour Sonarr → `http://sonarr:8989`
3. FlareSolverr si nécessaire : `Paramètres → Proxies → http://flaresolverr:8191`

#### Radarr / Sonarr
1. `Paramètres → Gestion des médias → Dossiers racine` : `/media/movies` ou `/media/tvseries`
2. `Paramètres → Clients de téléchargement → qBittorrent` :
   - Host : `rdtclient` | Port : `6500` | Catégorie : `radarr` ou `sonarr`
3. `Paramètres → Se connecter → Script` : `/scripts/mkclean.sh` (événements : Sur importation)

#### RDTClient
1. `Settings` → clé API de ton service debrid :
   - **Real-Debrid** : [real-debrid.com/apitoken](https://real-debrid.com/apitoken)
   - **AllDebrid** : [alldebrid.com/apikeys](https://alldebrid.com/apikeys/)
   - Autres services supportés : Premiumize, Debrid-Link, TorBox
2. `Settings → Download client → Provider` → choisir le service correspondant
3. `Settings → Download path` : `/data/downloads/rdtclient`

#### Seerr
1. Wizard → Plex : `http://host.docker.internal:32400`
2. `Paramètres → Services` : Radarr `http://radarr:7878` / Sonarr `http://sonarr:8989`

### 8. Récupérer les clés API pour Homepage

| Variable `.env` | Emplacement dans le service |
|---|---|
| `HOMEPAGE_PLEX_TOKEN` | Requête Plex Web → header `X-Plex-Token` dans DevTools |
| `HOMEPAGE_TAUTULLI_KEY` | Tautulli → `Paramètres → Interface web → Clé API` |
| `HOMEPAGE_SEERR_KEY` | Seerr → `Paramètres → Général → Clé API` |
| `HOMEPAGE_SONARR_KEY` | Sonarr → `Paramètres → Général → Clé API` |
| `HOMEPAGE_RADARR_KEY` | Radarr → `Paramètres → Général → Clé API` |
| `HOMEPAGE_PROWLARR_KEY` | Prowlarr → `Paramètres → Général → Clé API` |
| `HOMEPAGE_DUPLICATI_TOKEN` | Duplicati → `Paramètres → Jeton d'accès permanent` |

Puis redémarrer Homepage :
```bash
cd /opt/homelab
# Éditer .env avec les clés
nano .env
docker compose restart homepage
```

---

## Configuration manuelle (migration depuis un setup existant)

```bash
cp .env.example .env
nano .env          # Remplir toutes les valeurs

# Sécuriser le fichier
chmod 600 .env

# Réseau Docker
docker network create proxy_manager

# Écrire le chemin absolu dans le conf updater
echo "$(pwd)/docker-compose.yml" > updater/containers-to-update.conf

# Créer les répertoires de données
source .env
mkdir -p "${MEDIA_DIR}"/{movies,tvseries,animes}
mkdir -p "${DOWNLOADS_DIR}"/rdtclient

# Démarrer (proxy-manager en premier pour initialiser le réseau)
docker compose up -d proxy-manager
sleep 5
docker compose up -d
```

> **NPM** : première connexion avec `admin@example.com / changeme`, puis changer email et mot de passe pour les valeurs définies dans `.env` (`HOMEPAGE_NPM_EMAIL` / `HOMEPAGE_NPM_PASSWORD`).

---

## Disques supplémentaires (USB, NAS)

**1. Ajouter dans `.env` :**
```bash
USB_MEDIA_DIR_1=/mnt/usb1/media
```

**2. Décommenter dans `compose/homepage/docker-compose.yml` :**
```yaml
- ${USB_MEDIA_DIR_1}:/host/usb1:ro
```

**3. Décommenter dans `compose/homepage/config/services.yaml` :**
```yaml
- USB-1:
    widget:
        type: glances
        url: http://glances:61208
        version: 4
        metric: fs:/host/usb1
```

**4. Redémarrer :**
```bash
docker compose restart homepage glances
```

---

## Mise à jour automatique

Cron configuré par `setup.sh` dans `/etc/cron.d/homelab-updater` :
```
0 4 * * 0 root /opt/homelab/updater/updater.sh >> /var/log/homelab-updater.log 2>&1
```

Le script `updater/updater.sh` :
1. `apt upgrade` du système
2. `docker compose pull` des nouvelles images
3. `docker compose up -d --force-recreate --remove-orphans` (résout les conflits de noms)
4. `docker image prune -f` (libère de l'espace)
5. **notification ntfy** de succès/échec si `NTFY_URL` + `NTFY_TOKEN` sont définis dans `.env` (voir `.env.example` pour créer un token write-only dédié)

### Rotation des logs Docker

Par défaut, les logs `json-file` des conteneurs grossissent **sans limite** et peuvent saturer le disque. Créer `/etc/docker/daemon.json` puis redémarrer Docker (`sudo systemctl restart docker`) :

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
```

```bash
# Mise à jour manuelle
sudo ./updater/updater.sh

# Logs
tail -f /var/log/homelab-updater.log
```

---

## Optimisation MKV (mkclean)

`mkclean` optimise les fichiers `.mkv` automatiquement après chaque import dans Radarr/Sonarr via un script post-import. Voir [scripts/README.md](scripts/README.md).

---

## Sécurité

| Mesure | Détail |
|---|---|
| `.env` en `chmod 600` | Lisible uniquement par root |
| `.env` dans `.gitignore` | Jamais versionné ni partagé |
| Mots de passe aléatoires | 24 caractères générés par `setup.sh` |
| Port 81 NPM sur `127.0.0.1` | Admin NPM non exposé publiquement |
| TLS sur tous les accès publics | Let's Encrypt via NPM |
| Volumes en `:ro` | docker.sock, `/`, médias en lecture seule |
| Aucun port inutile exposé | Services accessibles uniquement via NPM |

---

## Commandes utiles

```bash
# État de tous les conteneurs
docker compose ps

# Logs d'un service (ex: radarr)
docker compose logs -f radarr

# Redémarrer un service
docker compose restart homepage

# Arrêter toute la stack
docker compose down

# Démarrer une stack spécifique
docker compose up -d radarr sonarr

# Mise à jour manuelle
sudo ./updater/updater.sh

# Vérifier la config résolue (variables substituées)
docker compose config
```

---

## Dépannage

**Conteneur qui ne démarre pas :**
```bash
docker compose logs <service>
```

**Erreur "network proxy_manager not found" :**
```bash
docker network create proxy_manager && docker compose up -d
```

**Conflit de nom de conteneur :**
```bash
docker compose up -d --force-recreate
```

**Homepage : widgets vides après démarrage :**
Les clés API doivent être renseignées dans `.env` après la première configuration de chaque service.
Voir section "Récupérer les clés API" ci-dessus.

**mkclean incompatible (architecture ARM, etc.) :**
Voir [scripts/README.md](scripts/README.md) — section "Compiler depuis les sources".

**Plex non accessible depuis Tautulli/Seerr :**
Vérifier que `extra_hosts: host.docker.internal:host-gateway` est présent dans les composes tautulli et seerr (déjà configuré par défaut).
