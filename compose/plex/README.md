# plex — Serveur Média

Plex Media Server pour streamer films, séries et animes sur tous tes appareils.

## Service

- **Port** : `32400` (réseau `host` — accès direct)
- **Config** : `compose/plex/config/` (non versionné)
- **URL locale** : `http://<IP_SERVEUR>:32400/web`
- **URL publique** : `https://plex.${DOMAIN}` (via NPM)

> Plex utilise `network_mode: host` pour le fonctionnement optimal de la découverte réseau local (GDM). Le reverse proxy via Nginx Proxy Manager reste possible en pointant vers `<IP_SERVEUR>:32400`.

## Post-install

1. Accéder à `http://<IP_SERVEUR>:32400/web` depuis le réseau local
2. Si `PLEX_CLAIM` est défini dans `.env`, le serveur est automatiquement associé à ton compte Plex
3. Ajouter les bibliothèques :
   - Films → `/media/movies`
   - Séries → `/media/tvseries`
   - Animes → `/media/animes`
4. `Paramètres → Remote Access` → activer l'accès distant
5. Récupérer le **token Plex** pour le widget Homepage :
   - Dans Plex Web → une URL de requête → chercher `X-Plex-Token` dans les paramètres réseau du navigateur (DevTools → Network)
   - Ou via : `Settings → Troubleshooting → Download Logs` → chercher `X-Plex-Token` dans les logs
   - Mettre dans `.env` (`HOMEPAGE_PLEX_TOKEN`)

## Transcodage matériel (Intel Quick Sync)

Si le serveur dispose d'un GPU Intel, décommenter dans `docker-compose.yml` :

```yaml
devices:
  - /dev/dri:/dev/dri
```

Et dans Plex : `Paramètres → Transcoder → Activer le transcodage accéléré par le matériel`

## Volumes

| Volume hôte | Conteneur | Description |
|---|---|---|
| `compose/plex/config/` | `/config` | Configuration et base de données Plex |
| `${MEDIA_DIR}` | `/media` | Bibliothèque multimédia |

## Variables d'environnement utilisées

| Variable | Description |
|---|---|
| `PUID` / `PGID` | UID/GID de l'utilisateur système |
| `PLEX_CLAIM` | Token de claim (valide 4 min — obtenir sur plex.tv/claim) |
