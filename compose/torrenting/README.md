# torrenting — Prowlarr · RDTClient

Gestion des indexeurs et téléchargement via Real-Debrid.

## Services

### Prowlarr — Gestionnaire d'indexeurs
- **Port** : `9696`
- **Config** : `compose/torrenting/prowlarr-config/` (non versionné)
- **URL** : `https://prowlarr.${DOMAIN}`

Prowlarr est le hub central d'indexeurs : il les configure une seule fois et les synchronise automatiquement avec Radarr et Sonarr.

**Post-install :**
1. `Paramètres → Indexeurs` → ajouter les indexeurs souhaités
2. `Paramètres → Apps` → connecter Radarr (host: `radarr:7878`) et Sonarr (host: `sonarr:8989`) avec leurs clés API respectives → les indexeurs se synchronisent automatiquement
3. `Paramètres → Proxies` → ajouter FlareSolverr si des indexeurs nécessitent le bypass Cloudflare
   - Type : FlareSolverr, URL : `http://flaresolverr:8191`
4. `Paramètres → Général` → noter la clé API → mettre dans `.env` (`HOMEPAGE_PROWLARR_KEY`)

### RDTClient — Client de téléchargement debrid
- **Port** : `6500`
- **Config** : `compose/torrenting/rdtclient-config/` (non versionné)
- **URL** : `https://rdt.${DOMAIN}`

RDTClient est un client torrent qui débride automatiquement les liens via un service debrid, offrant des vitesses de téléchargement maximales sans tracker public.

**Services debrid supportés :**
| Service | Lien clé API |
|---|---|
| Real-Debrid | [real-debrid.com/apitoken](https://real-debrid.com/apitoken) |
| AllDebrid | [alldebrid.com/apikeys](https://alldebrid.com/apikeys/) |
| Premiumize | [premiumize.me/account](https://www.premiumize.me/account) |
| Debrid-Link | [debrid-link.com/webapp/apikey](https://debrid-link.com/webapp/apikey) |
| TorBox | [torbox.app/settings](https://torbox.app/settings) |

**Post-install :**
1. `Settings → Provider` → choisir le service souhaité
2. `Settings` → entrer la clé API du service
3. `Settings → Download path` → définir : `/data/downloads/rdtclient`
4. Dans Radarr/Sonarr : `Paramètres → Clients de téléchargement → +`
   - Type : qBittorrent, Host : `rdtclient`, Port : `6500`
   - Catégorie : `radarr` ou `sonarr`

## Volumes

| Volume hôte | Conteneur | Description |
|---|---|---|
| `prowlarr-config/` | `/config` | Configuration Prowlarr |
| `rdtclient-config/` | `/data/db` | Base de données RDTClient |
| `${DOWNLOADS_DIR}/rdtclient` | `/data/downloads/rdtclient` | Fichiers téléchargés |

## Variables d'environnement utilisées

| Variable | Description |
|---|---|
| `PUID` / `PGID` | UID/GID de l'utilisateur système |
| `DOWNLOADS_DIR` | Chemin des téléchargements sur l'hôte |
