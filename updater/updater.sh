#!/bin/bash
# =============================================================================
# HOMELAB — Script de mise à jour des conteneurs Docker
# Cron recommandé : 0 4 * * 0 root /path/to/homelab/updater/updater.sh >> /var/log/homelab-updater.log 2>&1
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DCOMPOSE="$(dirname "${BASH_SOURCE[0]}")/containers-to-update.conf"

apt update && apt upgrade -y && apt autoremove -y

if [[ ! -f "$DCOMPOSE" ]]; then
    echo "[ERROR] Fichier de configuration introuvable : $DCOMPOSE"
    exit 1
fi

grep -v '^#' "$DCOMPOSE" | grep -v '^$' |
while read -r compfile; do
    if [[ -f "$compfile" ]]; then
        dir=$(dirname "$compfile")
        filename=$(basename "$compfile")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mise à jour : $compfile"
        cd "$dir"
        # --force-recreate recrée les conteneurs même si le nom est déjà utilisé
        docker compose pull \
            && docker compose -f "$filename" up -d --force-recreate --remove-orphans \
            && docker image prune -f
        cd "$REPO_DIR"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] Fichier introuvable : $compfile"
    fi
done
