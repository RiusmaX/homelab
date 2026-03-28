# tautulli — Statistiques Plex

Tautulli surveille l'activité de Plex et génère des statistiques détaillées : qui regarde quoi, quand, depuis quel appareil, quelle qualité de transcodage, etc.

## Service

- **Port** : `8181`
- **Config** : `compose/tautulli/config/` (non versionné)
- **URL** : `https://tautulli.${DOMAIN}`

## Post-install

1. Au premier lancement, renseigner l'adresse du serveur Plex :
   - Host : `<IP_SERVEUR>` (ou `host.docker.internal` si Plex est sur le même hôte)
   - Port : `32400`
   - Token Plex : le même que `HOMEPAGE_PLEX_TOKEN`
2. Tautulli commence à collecter les données en temps réel
3. `Paramètres → API` → noter la clé API → mettre dans `.env` (`HOMEPAGE_TAUTULLI_KEY`)

## Notifications (optionnel)

Tautulli peut envoyer des notifications via ntfy :
`Paramètres → Notifications → Ajouter un agent de notification → Webhook`
- URL : `http://ntfy:80/plex-activity`
- Méthode : POST

## Volumes

| Volume hôte | Conteneur | Description |
|---|---|---|
| `compose/tautulli/config/` | `/config` | Configuration et base de données Tautulli |

## Variables d'environnement utilisées

| Variable | Description |
|---|---|
| `PUID` / `PGID` | UID/GID de l'utilisateur système |
| `TZ` | Timezone |
