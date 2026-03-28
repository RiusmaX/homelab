# ntfy — Notifications push

ntfy est un serveur de notifications push auto-hébergé. Il permet d'envoyer des alertes depuis n'importe quel service (Radarr, Sonarr, Duplicati, scripts...) vers les applications mobiles ou le navigateur.

## Service

- **Port** : `80` (interne)
- **Config** : `compose/ntfy.sh/config/` (non versionné)
- **Data** : `compose/ntfy.sh/data/` (non versionné)
- **URL** : `https://ntfy.${DOMAIN}`

## Utilisation

### Depuis un navigateur ou curl
```bash
# Envoyer une notification sur le topic "homelab"
curl -d "Mise à jour terminée" https://ntfy.yourdomain.com/homelab
```

### App mobile
Installer l'app [ntfy](https://ntfy.sh/#download) et s'abonner au topic `https://ntfy.yourdomain.com/homelab`.

## Intégrations

### Radarr / Sonarr
`Paramètres → Se connecter → Webhook`
- URL : `https://ntfy.yourdomain.com/radarr` (ou `sonarr`)
- Méthode : POST
- Événements : `Sur importation`, `Sur mise à niveau`

### Duplicati
`Paramètres → Notifications → Envoyer un message HTTP`
- URL : `http://ntfy:80/duplicati`

### Script updater
Ajouter en fin de `updater/updater.sh` :
```bash
curl -s -d "Mise à jour des conteneurs terminée" http://ntfy:80/homelab-updates
```

## Configuration avancée

Fichier de configuration : `compose/ntfy.sh/config/server.yml`

```yaml
# Exemple de config avec authentification
auth-file: "/var/lib/ntfy/user.db"
auth-default-access: "deny-all"
base-url: "https://ntfy.yourdomain.com"
```

## Variables d'environnement utilisées

| Variable | Description |
|---|---|
| `TZ` | Timezone |
| `DOMAIN` | Domaine (pour `NTFY_BASE_URL`) |
