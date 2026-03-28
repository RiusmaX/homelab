#!/bin/bash

LOGFILE="/scripts/mkclean.log"
BINARY="/scripts/mkclean-bin"

# 1. Gestion du Ping de Test
if [ "$radarr_eventtype" == "Test" ] || [ "$sonarr_eventtype" == "Test" ]; then
    echo "$(date): Ping de test reçu depuis l'interface. OK." >> $LOGFILE
    exit 0
fi

# 2. Récupération du chemin exact du FICHIER
FILE_PATH="${radarr_moviefile_path:-$sonarr_episodefile_path}"

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    echo "$(date): Erreur : Fichier introuvable ou chemin vide ($FILE_PATH)" >> $LOGFILE
    exit 1
fi

FILENAME=$(basename "$FILE_PATH")

# 3. L'ASTUCE I/O : Le buffer SSD
# On écrit le fichier temporaire dans /downloads (qui correspond à ton SSD physique)
TEMP_CLEAN="/downloads/mkclean_tmp_$FILENAME"

echo "$(date): Début optimisation pour $FILENAME (Buffer SSD)" >> $LOGFILE

# 4. Execution (Lecture HDD -> Ecriture SSD)
$BINARY --optimize "$FILE_PATH" "$TEMP_CLEAN" >> $LOGFILE 2>&1

# 5. Remplacement (Lecture SSD -> Ecriture séquentielle HDD)
if [ -f "$TEMP_CLEAN" ]; then
    mv "$TEMP_CLEAN" "$FILE_PATH"
    chmod 664 "$FILE_PATH"
    echo "$(date): Succès : $FILENAME est optimisé et replacé." >> $LOGFILE
else
    echo "$(date): Echec : Le binaire n'a pas produit de fichier." >> $LOGFILE
    exit 1
fi
