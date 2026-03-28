# Homelab — Self-hosted media & services stack

Stack Docker Compose complète, sécurisée et déployable en one-click sur un serveur Ubuntu/Debian vierge. Tous les secrets sont dans `.env` (jamais versionné). Les configurations sont versionnées et partageables publiquement.

---

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
| **RDTClient** | Client Real-Debrid | 6500 | [→](compose/torrenting/README.md) |
| **pyLoad** | Téléchargements HTTP | 8000 | [→](compose/pyload/README.md) |
| **Duplicati** | Sauvegardes chiffrées | 8200 | [→](compose/duplicati/README.md) |
| **ntfy** | Notifications push | 80 | [→](compose/ntfy.sh/README.md) |
| **Homepage** | Dashboard unifié | 3000 | [→](compose/homepage/README.md) |
| **Glances** | Monitoring système | 61208 | [→](compose/homepage/README.md) |

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
   ├── radarr:7878  ──┐
   ├── sonarr:8989    ├─ arr-stack
   ├── seerr:5055     │
   ├── flaresolverr:8191 ─┘
   ├── prowlarr:9696 ─┐
   ├── rdtclient:6500  ├─ torrenting
   │                  ─┘
   ├── tautulli:8181
   ├── pyload:8000
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
│   ├── pyload/
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
- **Ports 80 et 443** ouverts depuis Internet (firewall / NAT box)
- Optionnel : compte [Real-Debrid](https://real-debrid.com) pour RDTClient

---

## Déploiement sur un serveur vierge

### 1. Cloner le repo

```bash
# Sur le serveur, en tant que root
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

Les mots de passe (RDTClient, pyLoad, NPM) sont générés automatiquement et affichés une seule fois à la fin.

Ensuite `setup.sh` :
1. Installe Docker Engine + Compose plugin
2. Crée l'utilisateur système
3. Écrit le fichier `.env`
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
pyload.yourdomain.com        → <IP_PUBLIQUE>
duplicati.yourdomain.com     → <IP_PUBLIQUE>
ntfy.yourdomain.com          → <IP_PUBLIQUE>
tautulli.yourdomain.com      → <IP_PUBLIQUE>
stats.yourdomain.com         → <IP_PUBLIQUE>
proxy-manager.yourdomain.com → <IP_PUBLIQUE>
```

### 4. Configurer Nginx Proxy Manager

Accéder à **`http://<IP_SERVEUR>:81`** (port lié à l'interface locale, non exposé publiquement).

- Email : `HOMEPAGE_NPM_EMAIL`
- Mot de passe : `HOMEPAGE_NPM_PASSWORD`

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
| `pyload.domaine.com` | `pyload` | `8000` | ✅ |
| `duplicati.domaine.com` | `duplicati` | `8200` | ✅ |
| `ntfy.domaine.com` | `ntfy` | `80` | ✅ |
| `tautulli.domaine.com` | `tautulli` | `8181` | ✅ |
| `stats.domaine.com` | `glances` | `61208` | ✅ |
| `proxy-manager.domaine.com` | `proxy-manager` | `81` | ✅ |

> SSL : `Request a new SSL Certificate` → cocher `Force SSL` + `HTTP/2 Support`

### 5. Configurer Plex

1. Aller sur `http://<IP_SERVEUR>:32400/web`
2. Ajouter les bibliothèques :
   - Films → `/media/movies`
   - Séries → `/media/tvseries`
   - Animes → `/media/animes`
3. Activer l'accès distant dans les paramètres

### 6. Configurer la stack arr

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
1. `Settings` → clé API Real-Debrid depuis [real-debrid.com/apitoken](https://real-debrid.com/apitoken)
2. `Settings → Download path` : `/data/downloads/rdtclient`

#### Seerr
1. Wizard → Plex : `http://host.docker.internal:32400`
2. `Paramètres → Services` : Radarr `http://radarr:7878` / Sonarr `http://sonarr:8989`

### 7. Récupérer les clés API pour Homepage

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
nano .env

# Réseau Docker
docker network create proxy_manager

# Écrire le chemin dans le conf updater
echo "$(pwd)/docker-compose.yml" > updater/containers-to-update.conf

# Créer les répertoires
source .env
mkdir -p "${MEDIA_DIR}"/{movies,tvseries,animes}
mkdir -p "${DOWNLOADS_DIR}"/{rdtclient,pyload}

# Démarrer
docker compose up -d
```

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
