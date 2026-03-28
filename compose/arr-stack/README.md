# arr-stack — Radarr · Sonarr · Seerr · FlareSolverr

Stack de gestion automatisée des médias. Les quatre services fonctionnent ensemble pour trouver, télécharger et organiser films et séries.

## Architecture

```
Seerr (demandes utilisateurs)
  └─→ Radarr / Sonarr (recherche & gestion)
         └─→ Prowlarr (indexeurs) — voir compose/torrenting/
               └─→ FlareSolverr (bypass Cloudflare)
                     └─→ RDTClient (téléchargement Real-Debrid)
```

## Services

### Radarr — Gestion des films
- **Port** : `7878`
- **Config** : `compose/arr-stack/radarr-config/` (non versionné)
- **URL** : `https://movies.${DOMAIN}`

**Post-install :**
1. `Paramètres → Gestion des médias` → définir le chemin racine `/media/movies`
2. `Paramètres → Indexeurs` → connecter Prowlarr (sync automatique)
3. `Paramètres → Clients de téléchargement` → ajouter RDTClient (host: `rdtclient`, port: `6500`)
4. `Paramètres → Se connecter` → ajouter le script mkclean (voir [scripts/README.md](../../scripts/README.md))
5. `Paramètres → Général` → noter la clé API → mettre dans `.env` (`HOMEPAGE_RADARR_KEY`)

### Sonarr — Gestion des séries
- **Port** : `8989`
- **Config** : `compose/arr-stack/sonarr-config/` (non versionné)
- **URL** : `https://tv.${DOMAIN}`

**Post-install :** même étapes que Radarr, chemin racine `/media/tvseries`

### Seerr — Interface de demandes
- **Port** : `5055`
- **Config** : `compose/arr-stack/seerr-config/` (non versionné)
- **URL** : `https://seer.${DOMAIN}`

**Post-install :**
1. Connecter Plex lors du wizard initial
2. `Paramètres → Services` → ajouter Radarr et Sonarr
3. `Paramètres → Général` → noter la clé API → mettre dans `.env` (`HOMEPAGE_SEERR_KEY`)

### FlareSolverr — Bypass Cloudflare
- **Port** : `8191` (interne uniquement)
- Pas d'interface web
- Se configure dans Prowlarr : `Paramètres → Indexeurs → Proxies → FlareSolverr`
  - URL : `http://flaresolverr:8191`

## Volumes

| Volume hôte | Conteneur | Description |
|---|---|---|
| `radarr-config/` | `/config` | Configuration Radarr (BDD, profils, etc.) |
| `sonarr-config/` | `/config` | Configuration Sonarr |
| `seerr-config/` | `/app/config` | Configuration Seerr |
| `${MEDIA_DIR}` | `/media` | Bibliothèque multimédia |
| `${DOWNLOADS_DIR}/rdtclient` | `/downloads` | Téléchargements RDTClient + buffer SSD mkclean |
| `./scripts/` | `/scripts` | Scripts mkclean partagés |

## Variables d'environnement utilisées

| Variable | Description |
|---|---|
| `PUID` / `PGID` | UID/GID de l'utilisateur système |
| `TZ` | Timezone |
| `MEDIA_DIR` | Chemin du répertoire médias sur l'hôte |
| `DOWNLOADS_DIR` | Chemin des téléchargements sur l'hôte |
