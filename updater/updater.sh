#!/bin/bash
# =============================================================================
# HOMELAB — Script de mise à jour des conteneurs Docker
# Cron recommandé : 0 4 * * 0 root /path/to/homelab/updater/updater.sh >> /var/log/homelab-updater.log 2>&1
# =============================================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DCOMPOSE="$(dirname "${BASH_SOURCE[0]}")/containers-to-update.conf"

# Charge .env pour récupérer NTFY_URL / NTFY_TOKEN (notification optionnelle)
if [[ -f "$REPO_DIR/.env" ]]; then
    set -a; . "$REPO_DIR/.env"; set +a
fi

# notify <titre> <priorité> <tags> <message>
# Ne fait rien si NTFY_URL ou NTFY_TOKEN ne sont pas définis dans .env
notify() {
    [[ -z "$NTFY_URL" || -z "$NTFY_TOKEN" ]] && return 0
    curl -fsS -m 10 \
        -H "Authorization: Bearer $NTFY_TOKEN" \
        -H "Title: $1" \
        -H "Priority: $2" \
        -H "Tags: $3" \
        -d "$4" \
        "$NTFY_URL" >/dev/null 2>&1
}

START=$(date '+%Y-%m-%d %H:%M:%S')

apt update && apt upgrade -y && apt autoremove -y

if [[ ! -f "$DCOMPOSE" ]]; then
    echo "[ERROR] Fichier de configuration introuvable : $DCOMPOSE"
    notify "Homelab — échec de mise à jour" "high" "rotating_light" "Config updater introuvable : $DCOMPOSE"
    exit 1
fi

OK=""
FAILED=""

while read -r compfile; do
    [[ -z "$compfile" ]] && continue
    if [[ -f "$compfile" ]]; then
        dir=$(dirname "$compfile")
        filename=$(basename "$compfile")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Mise à jour : $compfile"
        cd "$dir"
        # --force-recreate recrée les conteneurs même si le nom est déjà utilisé
        if docker compose pull \
            && docker compose -f "$filename" up -d --force-recreate --remove-orphans; then
            docker image prune -f >/dev/null 2>&1
            OK="$OK $compfile"
        else
            FAILED="$FAILED $compfile"
        fi
        cd "$REPO_DIR"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] Fichier introuvable : $compfile"
        FAILED="$FAILED $compfile(introuvable)"
    fi
done < <(grep -v '^#' "$DCOMPOSE" | grep -v '^$')

# Notification de fin (succès ou échec)
if [[ -n "$FAILED" ]]; then
    notify "Homelab — échec de mise à jour" "high" "rotating_light,docker" \
"Échec :$FAILED
OK :${OK:- (aucun)}
Démarré : $START"
else
    notify "Homelab — mise à jour OK" "default" "white_check_mark,docker" \
"Stacks à jour :$OK
Démarré : $START"
fi
