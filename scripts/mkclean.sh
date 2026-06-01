#!/bin/bash

LOGFILE="/scripts/mkclean.log"
BINARY="/scripts/mkclean-bin"
LOCKFILE="/scripts/mkclean.lock"
LOG_MAXSIZE=$((10 * 1024 * 1024))  # 10 Mo : au-delà, le log est tourné vers .1

# =============================================================================
# MODE WORKER — relancé en arrière-plan, traitement sérialisé (un seul à la fois)
# =============================================================================
if [ "$1" == "--worker" ]; then
    FILE_PATH="$2"
    FILENAME=$(basename "$FILE_PATH")
    TEMP_CLEAN="/downloads/mkclean_tmp_$FILENAME"

    # Verrou exclusif : radarr ET sonarr partagent /scripts, donc ce verrou
    # garantit qu'un seul mkclean tourne sur tout le serveur. Les autres jobs
    # attendent ici leur tour au lieu de saturer le disque en parallèle.
    exec 200>"$LOCKFILE"
    flock -x 200

    # Rotation simple du log (sous verrou → aucune course entre workers)
    if [ -f "$LOGFILE" ] && [ "$(wc -c < "$LOGFILE" 2>/dev/null || echo 0)" -gt "$LOG_MAXSIZE" ]; then
        mv -f "$LOGFILE" "$LOGFILE.1"
    fi

    # Le fichier a pu être déplacé/supprimé pendant l'attente dans la file
    if [ ! -f "$FILE_PATH" ]; then
        echo "$(date): [SKIP] $FILENAME a disparu avant traitement." >> "$LOGFILE"
        exit 0
    fi

    # Priorité CPU/IO basse pour ne pas étrangler Plex ni les imports en cours
    PRIO=""
    command -v nice   >/dev/null 2>&1 && PRIO="nice -n 19"
    command -v ionice >/dev/null 2>&1 && PRIO="$PRIO ionice -c 3"

    echo "$(date): Début optimisation pour $FILENAME (Buffer SSD)" >> "$LOGFILE"

    # Execution (Lecture HDD -> Ecriture SSD)
    $PRIO "$BINARY" --optimize "$FILE_PATH" "$TEMP_CLEAN" >> "$LOGFILE" 2>&1

    # Remplacement (Lecture SSD -> Ecriture séquentielle HDD)
    if [ -f "$TEMP_CLEAN" ]; then
        mv "$TEMP_CLEAN" "$FILE_PATH"
        chmod 664 "$FILE_PATH"
        echo "$(date): Succès : $FILENAME est optimisé et replacé." >> "$LOGFILE"
    else
        echo "$(date): Echec : Le binaire n'a pas produit de fichier ($FILENAME)." >> "$LOGFILE"
        exit 1
    fi
    exit 0
fi

# =============================================================================
# MODE HOOK — appelé par Radarr/Sonarr (Connect → Sur importation)
# =============================================================================

# 1. Gestion du Ping de Test
if [ "$radarr_eventtype" == "Test" ] || [ "$sonarr_eventtype" == "Test" ]; then
    echo "$(date): Ping de test reçu depuis l'interface. OK." >> "$LOGFILE"
    exit 0
fi

# 2. Récupération du chemin exact du FICHIER
FILE_PATH="${radarr_moviefile_path:-$sonarr_episodefile_path}"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo "$(date): Erreur : Fichier introuvable ou chemin vide ($FILE_PATH)" >> "$LOGFILE"
    exit 1
fi

# 3. On détache le traitement en arrière-plan et on rend la main immédiatement.
# Radarr/Sonarr n'attendent pas : les jobs s'empilent et sont traités un par un
# par le verrou flock du mode worker, ce qui supprime l'étranglement I/O.
nohup "$0" --worker "$FILE_PATH" >/dev/null 2>&1 &
echo "$(date): $(basename "$FILE_PATH") mis en file d'attente." >> "$LOGFILE"
exit 0
