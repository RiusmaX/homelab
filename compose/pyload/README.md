# pyload — Téléchargements HTTP/Hoster

pyLoad gère les téléchargements depuis les hébergeurs de fichiers (1fichier, Rapidgator, Uptobox...) avec support des comptes premium.

## Service

- **Port** : `8000`
- **Config** : `compose/pyload/config/` (non versionné)
- **URL** : `https://pyload.${DOMAIN}`

## Post-install

1. Accéder à l'interface web
2. Identifiants par défaut :
   - Login : `HOMEPAGE_PYLOAD_USERNAME` (défini dans `.env`, défaut: `pyload`)
   - Mot de passe : `HOMEPAGE_PYLOAD_PASSWORD` (généré par `setup.sh`)
3. `Paramètres → Plugins` → configurer les comptes des hébergeurs premium

## Script GetRealdebridToken

Si tu utilises Real-Debrid avec pyLoad, le script `GetRealdebridToken.py` (dans l'ancienne config) permet de récupérer le token OAuth. Voir la documentation du plugin pyLoad Real-Debrid.

## Volumes

| Volume hôte | Conteneur | Description |
|---|---|---|
| `compose/pyload/config/` | `/config` | Configuration et plugins pyLoad |
| `${DOWNLOADS_DIR}/pyload` | `/downloads` | Fichiers téléchargés |

## Variables d'environnement utilisées

| Variable | Description |
|---|---|
| `PUID` / `PGID` | UID/GID de l'utilisateur système |
| `TZ` | Timezone |
| `DOWNLOADS_DIR` | Chemin des téléchargements sur l'hôte |
