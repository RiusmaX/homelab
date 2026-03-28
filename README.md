# Homelab — Self-hosted media & services stack

Stack Docker Compose complète et déployable en one-click sur un serveur Ubuntu/Debian.

## Services inclus

| Service | Rôle |
|---|---|
| **Nginx Proxy Manager** | Reverse proxy + certificats TLS Let's Encrypt |
| **Plex** | Serveur média |
| **Tautulli** | Statistiques Plex |
| **Radarr** | Gestion des films |
| **Sonarr** | Gestion des séries |
| **Seerr** | Demandes de médias |
| **Prowlarr** | Indexeurs |
| **FlareSolverr** | Bypass Cloudflare pour les indexeurs |
| **RDTClient** | Client Real-Debrid |
| **pyLoad** | Téléchargements HTTP |
| **Duplicati** | Sauvegardes automatiques |
| **ntfy** | Notifications push |
| **Homepage** | Dashboard unifié |
| **Glances** | Monitoring système |

---

## Déploiement rapide (serveur neuf)

```bash
git clone https://github.com/ton-user/homelab.git
cd homelab
sudo ./setup.sh
```

Le script interactif :
1. Installe Docker
2. Crée l'utilisateur système
3. Génère les mots de passe aléatoires
4. Crée les répertoires de données
5. Crée le réseau Docker `proxy_manager`
6. Démarre toutes les stacks
7. Configure le cron de mise à jour

---

## Configuration manuelle (serveur existant)

```bash
cp .env.example .env
# Éditer .env avec vos valeurs
nano .env

# Créer le réseau Docker (si inexistant)
docker network create proxy_manager

# Démarrer
docker compose up -d
```

---

## Structure des répertoires

```
homelab/
├── .env.example          # Template de configuration (versionné)
├── .env                  # Configuration réelle (non versionné)
├── docker-compose.yml    # Compose racine avec includes
├── setup.sh              # Script d'installation one-click
├── compose/
│   ├── arr-stack/        # Radarr, Sonarr, Seerr, FlareSolverr
│   ├── duplicati/        # Sauvegardes
│   ├── homepage/         # Dashboard + configs YAML
│   ├── nginx-proxy-manager/
│   ├── ntfy.sh/          # Notifications
│   ├── plex/
│   ├── pyload/
│   ├── tautulli/
│   └── torrenting/       # Prowlarr, RDTClient
├── scripts/
│   └── init-alpine.sh    # Script init pour mkclean dans Radarr/Sonarr
└── updater/
    ├── updater.sh        # Mise à jour automatique des images
    └── containers-to-update.conf
```

---

## Récupération des clés API (après premier démarrage)

Après avoir lancé les services, récupérer les clés API et les mettre dans `.env` :

### Radarr / Sonarr / Prowlarr
`Paramètres → Général → Clé API`

```
HOMEPAGE_RADARR_KEY=...
HOMEPAGE_SONARR_KEY=...
HOMEPAGE_PROWLARR_KEY=...
```

### Tautulli
`Paramètres → Interface web → Clé API`

### Seerr
`Paramètres → Général → Clé API`

### Plex Token
```bash
# Récupérer depuis les logs Tautulli ou via :
curl -su "user:password" http://localhost:32400/myplex/account | grep -o 'authToken="[^"]*"'
```

### Duplicati — Token forever
Connexion à Duplicati → Paramètres → Jeton d'accès permanent.

### Homepage — après mise à jour des clés
```bash
cd homelab
# Mettre à jour .env avec les clés récupérées
docker compose restart homepage
```

---

## Mise à jour automatique

Un cron est configuré par `setup.sh` dans `/etc/cron.d/homelab-updater`.

Pour le configurer manuellement :
```bash
# /etc/cron.d/homelab-updater
0 4 * * 0 root /chemin/vers/homelab/updater/updater.sh >> /var/log/homelab-updater.log 2>&1
```

Mise à jour manuelle :
```bash
sudo ./updater/updater.sh
```

Consulter les logs :
```bash
tail -f /var/log/homelab-updater.log
```

---

## Disques supplémentaires (USB, NAS)

Pour monter des disques supplémentaires dans Homepage/Glances, éditer `compose/homepage/docker-compose.yml` :

```yaml
volumes:
  - ${USB_MEDIA_DIR_1}:/host/usb1:ro
  - ${USB_MEDIA_DIR_2}:/host/usb2:ro
```

Et décommenter les widgets correspondants dans `compose/homepage/config/services.yaml`.

---

## Sécurité

- Le fichier `.env` est en `chmod 600` et exclu de git
- Les mots de passe sont générés aléatoirement par `setup.sh`
- Nginx Proxy Manager gère les certificats TLS (Let's Encrypt)
- Seuls les ports 80 et 443 sont exposés publiquement

---

## Nginx Proxy Manager — premiers pas

1. Accéder à `http://<IP_SERVEUR>:81`
2. Connexion : email + mot de passe définis dans `.env` (`HOMEPAGE_NPM_EMAIL` / `HOMEPAGE_NPM_PASSWORD`)
3. Créer un proxy host pour chaque service :

| Domaine | Destination | Port |
|---|---|---|
| `home.yourdomain.com` | `homepage` | `3000` |
| `plex.yourdomain.com` | `<IP_SERVEUR>` | `32400` |
| `tv.yourdomain.com` | `sonarr` | `8989` |
| `movies.yourdomain.com` | `radarr` | `7878` |
| `seer.yourdomain.com` | `seerr` | `5055` |
| `prowlarr.yourdomain.com` | `prowlarr` | `9696` |
| `rdt.yourdomain.com` | `rdtclient` | `6500` |
| `pyload.yourdomain.com` | `pyload` | `8000` |
| `duplicati.yourdomain.com` | `duplicati` | `8200` |
| `ntfy.yourdomain.com` | `ntfy` | `80` |
| `tautulli.yourdomain.com` | `tautulli` | `8181` |
| `stats.yourdomain.com` | `glances` | `61208` |
