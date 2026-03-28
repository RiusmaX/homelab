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

### RDTClient — Client Real-Debrid
- **Port** : `6500`
- **Config** : `compose/torrenting/rdtclient-config/` (non versionné)
- **URL** : `https://rdt.${DOMAIN}`

RDTClient est un client torrent qui débride automatiquement les liens via Real-Debrid, offrant des vitesses de téléchargement maximales sans tracker public.

**Post-install :**
1. `Settings` → entrer la clé API Real-Debrid (obtenir sur [real-debrid.com/apitoken](https://real-debrid.com/apitoken))
2. `Settings → General` → définir le chemin des téléchargements : `/data/downloads/rdtclient`
3. Dans Radarr/Sonarr : `Paramètres → Clients de téléchargement → +`
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
