# nginx-proxy-manager — Reverse Proxy + TLS

Nginx Proxy Manager gère le routage HTTPS vers tous les services internes. Il génère et renouvelle automatiquement les certificats Let's Encrypt.

## Service

- **Port 80** : HTTP (redirection vers HTTPS)
- **Port 443** : HTTPS (proxy vers les services)
- **Port 81** : Interface d'administration — lié à `127.0.0.1`, accessible **uniquement depuis le réseau local** (non exposé publiquement)
- **Config** : `compose/nginx-proxy-manager/data/` et `letsencrypt/` (non versionnés)
- **URL admin** : `http://<IP_SERVEUR>:81`

## Premier accès

Identifiants par défaut générés par `setup.sh` :
- Email : `HOMEPAGE_NPM_EMAIL` (défini dans `.env`)
- Mot de passe : `HOMEPAGE_NPM_PASSWORD` (défini dans `.env`)

> Changer le mot de passe à la première connexion.

## Configuration des proxy hosts

Pour chaque service, créer un **Proxy Host** :

1. `Hosts → Proxy Hosts → Add Proxy Host`
2. Renseigner :
   - **Domain Names** : `service.yourdomain.com`
   - **Scheme** : `http`
   - **Forward Hostname / IP** : nom du conteneur Docker (ex: `radarr`, `sonarr`, `homepage`...)
   - **Forward Port** : port interne du service
3. Onglet **SSL** → `Request a new SSL Certificate` → activer `Force SSL` et `HTTP/2 Support`

### Table de référence

| Domaine | Conteneur | Port |
|---|---|---|
| `home.yourdomain.com` | `homepage` | `3000` |
| `plex.yourdomain.com` | `<IP_SERVEUR>` | `32400` |
| `tv.yourdomain.com` | `sonarr` | `8989` |
| `movies.yourdomain.com` | `radarr` | `7878` |
| `seer.yourdomain.com` | `seerr` | `5055` |
| `prowlarr.yourdomain.com` | `prowlarr` | `9696` |
| `rdt.yourdomain.com` | `rdtclient` | `6500` |
| `duplicati.yourdomain.com` | `duplicati` | `8200` |
| `ntfy.yourdomain.com` | `ntfy` | `80` |
| `tautulli.yourdomain.com` | `tautulli` | `8181` |
| `stats.yourdomain.com` | `glances` | `61208` |
| `proxy-manager.yourdomain.com` | `proxy-manager` | `81` |

## Prérequis DNS

Chaque sous-domaine doit pointer vers l'IP publique du serveur (enregistrement `A`).  
Pour un usage local uniquement : pointer vers l'IP LAN ou utiliser un DNS split-horizon.

## Volumes

| Volume hôte | Description |
|---|---|
| `compose/nginx-proxy-manager/data/` | Configuration NPM, BDD SQLite |
| `compose/nginx-proxy-manager/letsencrypt/` | Certificats TLS Let's Encrypt |
