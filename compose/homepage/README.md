# homepage — Dashboard · Glances

Dashboard unifié pour visualiser l'état de tous les services et les ressources système.

## Services

### Homepage — Dashboard
- **Port** : `3000`
- **Config** : `compose/homepage/config/` (**versionné** — YAML uniquement, pas de données runtime)
- **URL** : `https://home.${DOMAIN}`

### Glances — Monitoring système
- **Port** : `61208`
- **URL** : `https://stats.${DOMAIN}`
- Mode `pid: host` pour voir les processus de l'hôte

## Fichiers de configuration Homepage

Tous les fichiers dans `compose/homepage/config/` sont versionnés.  
Les secrets sont injectés via les variables d'environnement du `docker-compose.yml`.

| Fichier | Description |
|---|---|
| `services.yaml` | Services affichés + widgets |
| `settings.yaml` | Apparence, layout, thème |
| `widgets.yaml` | Widgets globaux (météo, ressources) |
| `bookmarks.yaml` | Liens rapides |
| `docker.yaml` | Connexion au socket Docker |
| `custom.css` | CSS personnalisé (layout 3 colonnes) |
| `custom.js` | JS personnalisé |

## Mise à jour des clés API

Après récupération des clés dans chaque service, les renseigner dans `.env` puis redémarrer :

```bash
# Éditer .env
nano .env

# Relancer uniquement homepage
docker compose restart homepage
```

La syntaxe `{{VARIABLE}}` dans `services.yaml` est résolue par Homepage depuis les variables d'environnement passées dans le `docker-compose.yml`.

## Disques supplémentaires

Pour afficher l'espace disque de disques USB/NAS supplémentaires :

1. Décommenter les volumes dans `docker-compose.yml` :
```yaml
- ${USB_MEDIA_DIR_1}:/host/usb1:ro
```

2. Décommenter les widgets dans `config/services.yaml` :
```yaml
- USB-1:
    widget:
        type: glances
        url: http://glances:61208
        version: 4
        metric: fs:/host/usb1
```

3. Redémarrer : `docker compose restart homepage glances`

## Variables d'environnement utilisées

| Variable | Description |
|---|---|
| `HOMEPAGE_ALLOWED_HOSTS` | Domaine autorisé (ex: `home.yourdomain.com`) |
| `DOMAIN` | Domaine principal |
| `SERVER_LAN_IP` | IP LAN pour le widget Plex |
| `HOMEPAGE_*_KEY` | Clés API des différents services |
| `HOMEPAGE_*_PASSWORD` | Mots de passe pour les widgets |
| `HOMEPAGE_WEATHER_*` | Localisation pour le widget météo |
