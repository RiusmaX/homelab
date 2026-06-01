# scripts/

Contient les scripts partagés entre les services (montés en volume dans les conteneurs).

## mkclean — Optimisation des fichiers MKV

[mkclean](https://www.matroska.org/downloads/mkclean.html) est un outil open-source qui réorganise et optimise les fichiers Matroska (`.mkv`). Il améliore la lecture et réduit la taille des fichiers en nettoyant les métadonnées inutiles.

### Intégration Radarr / Sonarr

`mkclean.sh` est appelé automatiquement en tant que **script personnalisé post-import** dans Radarr et Sonarr.

**Flux d'exécution :**
```
Film/série importé → Radarr/Sonarr → mkclean.sh → mkclean-bin --optimize → fichier remplacé
```

**L'astuce I/O buffer SSD :** le fichier temporaire est écrit dans `/downloads` (qui doit être sur un SSD rapide) avant d'être déplacé vers `/media` (HDD). Cela évite une lecture/écriture séquentielle lente sur le même disque.

**Sérialisation (anti-étranglement) :** lors d'un import en lot (saison complète, plusieurs films), Radarr/Sonarr déclenchent le hook une fois par fichier. Pour éviter que plusieurs `mkclean` saturent le disque en parallèle, le script :

- **rend la main immédiatement** à Radarr/Sonarr (le travail est détaché en arrière-plan via `nohup`), donc l'import n'est jamais bloqué ;
- traite les fichiers **un par un** grâce à un verrou `flock` (`/scripts/mkclean.lock`) partagé entre Radarr **et** Sonarr — un seul `mkclean` actif sur tout le serveur, les autres patientent dans la file ;
- s'exécute en **priorité CPU/IO basse** (`nice -n 19 ionice -c 3`) pour ne pas gêner Plex ni les imports en cours.

> Nécessite `flock`, `nohup`, `nice` et `ionice` dans le conteneur (présents par défaut dans les images linuxserver.io / busybox).

**Rotation du log :** `mkclean.log` est tourné vers `mkclean.log.1` dès qu'il dépasse 10 Mo, pour éviter qu'il grossisse sans fin.

### Configuration dans Radarr / Sonarr

1. Aller dans `Paramètres → Se connecter → Ajouter une connexion`
2. Choisir **Script personnalisé**
3. Renseigner :
   - **Chemin** : `/scripts/mkclean.sh`
   - **Arguments** : laisser vide
   - **Événements** : cocher `Sur importation`
4. Tester la connexion (envoie un événement `Test`)

Les logs mkclean sont consultables dans `/scripts/mkclean.log` (sur l'hôte : `scripts/mkclean.log` dans le volume).

### Fichiers

| Fichier | Description |
|---|---|
| `mkclean-bin` | Binaire ELF x86-64 compilé depuis les sources officielles |
| `mkclean.sh` | Script wrapper appelé par Radarr/Sonarr |
| `init-alpine.sh` | Script d'init conteneur : installe `gcompat`/`libc6-compat` pour que le binaire glibc fonctionne dans Alpine |

### Compiler depuis les sources (optionnel)

Si le binaire fourni ne fonctionne pas (architecture différente, etc.) :

```bash
sudo apt-get install -y cmake build-essential
git clone https://gitlab.com/mbunkus/mkvtoolnix.git  # ou télécharger mkclean séparément
# Source officielle : https://sourceforge.net/projects/matroska/files/mkclean/
tar -xzf mkclean-0.9.0.tar.bz2
cd mkclean-0.9.0
cmake . && make
cp mkclean/mkclean /path/to/homelab/scripts/mkclean-bin
```
