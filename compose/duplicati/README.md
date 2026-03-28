# duplicati — Sauvegardes automatiques

Duplicati effectue des sauvegardes incrémentales chiffrées vers une destination distante (cloud, NAS, SFTP...).

## Service

- **Port** : `8200`
- **Config** : `compose/duplicati/config/` (non versionné)
- **URL** : `https://duplicati.${DOMAIN}`

> Duplicati tourne en `PUID=0` (root) pour avoir accès à l'ensemble du système de fichiers de l'hôte monté en `/data/host`.

## Post-install

1. Accéder à l'interface web
2. Créer une sauvegarde :
   - **Source** : `/data/host/home/<SYSTEM_USER>/homelab` (le repo IaC lui-même)
   - **Destination** : ton service cloud préféré (Backblaze B2, Google Drive, OneDrive, SFTP...)
   - **Chiffrement** : AES-256 avec une passphrase forte
   - **Planification** : ex. tous les jours à 3h00

### Jeton d'accès permanent (widget Homepage)

Duplicati utilise un jeton d'accès pour l'API sans session :

1. `Paramètres → Jeton d'accès permanent` → générer
2. Copier le jeton JWT → mettre dans `.env` (`HOMEPAGE_DUPLICATI_TOKEN`)
3. `docker compose restart homepage`

## Ce qu'il faut sauvegarder

| Priorité | Source | Description |
|---|---|---|
| **Critique** | `homelab/` | Repo IaC (config, scripts) |
| **Important** | `radarr-config/`, `sonarr-config/` | Profils, historique d'import |
| **Important** | `seerr-config/` | Historique des demandes |
| **Important** | `tautulli/config/` | Statistiques de visionnage |
| **Important** | `nginx-proxy-manager/data/` | Config proxy + certificats |
| **Optionnel** | `plex/config/` | Volumineux (cache, BDD) |

## Volumes

| Volume hôte | Conteneur | Description |
|---|---|---|
| `compose/duplicati/config/` | `/data/Duplicati` | Configuration et historique Duplicati |
| `/` | `/data/host` | Accès complet au système de fichiers hôte (lecture seule) |
