#!/usr/bin/env bash
# =============================================================================
# HOMELAB — Script de déploiement one-click
# Usage: sudo ./setup.sh
# =============================================================================
set -euo pipefail

# --- Couleurs & helpers -------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERR]${NC}  $*"; exit 1; }
ask()     { echo -e "${BOLD}$*${NC}"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${REPO_DIR}/.env"
ENV_EXAMPLE="${REPO_DIR}/.env.example"

# --- Vérifications préalables -------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Ce script doit être exécuté en root ou avec sudo."
    fi
}

check_os() {
    if ! grep -qi 'ubuntu\|debian' /etc/os-release 2>/dev/null; then
        warn "OS non testé. Ce script cible Ubuntu/Debian. Continuer quand même ? (y/N)"
        read -r confirm
        [[ "$confirm" == "y" || "$confirm" == "Y" ]] || error "Annulé."
    fi
}

# --- Installation Docker ------------------------------------------------------
install_docker() {
    if command -v docker &>/dev/null; then
        success "Docker déjà installé ($(docker --version))"
        return
    fi
    info "Installation de Docker..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    success "Docker installé."
}

# --- Création de l'utilisateur système ----------------------------------------
create_system_user() {
    local username="$1"
    if id "$username" &>/dev/null; then
        success "Utilisateur '$username' existe déjà (UID=$(id -u "$username"))"
    else
        info "Création de l'utilisateur '$username'..."
        useradd -m -s /bin/bash "$username"
        success "Utilisateur '$username' créé."
    fi
    # Ajouter au groupe docker
    usermod -aG docker "$username"
    success "Utilisateur '$username' ajouté au groupe docker."
}

# --- Génération de mot de passe aléatoire ------------------------------------
gen_password() {
    tr -dc 'A-Za-z0-9!@#%^&*' </dev/urandom | head -c 24
}

# --- Configuration du fichier .env --------------------------------------------
configure_env() {
    if [[ -f "$ENV_FILE" ]]; then
        warn ".env existe déjà. Ignorer la configuration ? (Y/n)"
        read -r skip
        [[ "$skip" == "n" || "$skip" == "N" ]] || { info "Fichier .env conservé."; return; }
    fi

    echo ""
    echo -e "${BOLD}=== Configuration de l'environnement ===${NC}"
    echo ""

    # Utilisateur système
    ask "Nom de l'utilisateur Linux qui exécutera les services [homelab] :"
    read -r SYSTEM_USER
    SYSTEM_USER="${SYSTEM_USER:-homelab}"

    # UID/GID automatiquement déterminés après création de l'utilisateur
    create_system_user "$SYSTEM_USER"
    local PUID; PUID=$(id -u "$SYSTEM_USER")
    local PGID; PGID=$(id -g "$SYSTEM_USER")
    success "UID=$PUID / GID=$PGID"

    # Timezone
    ask "Timezone [Europe/Paris] :"
    read -r TZ
    TZ="${TZ:-Europe/Paris}"

    # Domaine
    ask "Nom de domaine principal (ex: mondomaine.com) :"
    read -r DOMAIN
    [[ -n "$DOMAIN" ]] || error "Le domaine est requis."

    # IP LAN
    ask "IP LAN du serveur (ex: 192.168.1.100) :"
    read -r SERVER_LAN_IP
    SERVER_LAN_IP="${SERVER_LAN_IP:-192.168.1.100}"

    # Chemins
    local DEFAULT_HOME="/home/${SYSTEM_USER}"
    ask "Répertoire des médias [${DEFAULT_HOME}/media] :"
    read -r MEDIA_DIR
    MEDIA_DIR="${MEDIA_DIR:-${DEFAULT_HOME}/media}"

    ask "Répertoire des téléchargements [${DEFAULT_HOME}/downloads] :"
    read -r DOWNLOADS_DIR
    DOWNLOADS_DIR="${DOWNLOADS_DIR:-${DEFAULT_HOME}/downloads}"

    # Plex claim
    ask "Token Plex Claim (https://www.plex.tv/claim/ — optionnel, laisser vide si déjà configuré) :"
    read -r PLEX_CLAIM

    # Credentials auto-générés
    local RDTCLIENT_PASS; RDTCLIENT_PASS=$(gen_password)
    local PYLOAD_PASS; PYLOAD_PASS=$(gen_password)
    local NPM_PASS; NPM_PASS=$(gen_password)

    ask "Email admin Nginx Proxy Manager [admin@${DOMAIN}] :"
    read -r NPM_EMAIL
    NPM_EMAIL="${NPM_EMAIL:-admin@${DOMAIN}}"

    # Écriture du .env
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    sed -i "s|^SYSTEM_USER=.*|SYSTEM_USER=${SYSTEM_USER}|" "$ENV_FILE"
    sed -i "s|^PUID=.*|PUID=${PUID}|" "$ENV_FILE"
    sed -i "s|^PGID=.*|PGID=${PGID}|" "$ENV_FILE"
    sed -i "s|^TZ=.*|TZ=${TZ}|" "$ENV_FILE"
    sed -i "s|^DOMAIN=.*|DOMAIN=${DOMAIN}|" "$ENV_FILE"
    sed -i "s|^SERVER_LAN_IP=.*|SERVER_LAN_IP=${SERVER_LAN_IP}|" "$ENV_FILE"
    sed -i "s|^MEDIA_DIR=.*|MEDIA_DIR=${MEDIA_DIR}|" "$ENV_FILE"
    sed -i "s|^DOWNLOADS_DIR=.*|DOWNLOADS_DIR=${DOWNLOADS_DIR}|" "$ENV_FILE"
    sed -i "s|^PLEX_CLAIM=.*|PLEX_CLAIM=${PLEX_CLAIM}|" "$ENV_FILE"
    sed -i "s|^HOMEPAGE_RDTCLIENT_PASSWORD=.*|HOMEPAGE_RDTCLIENT_PASSWORD=${RDTCLIENT_PASS}|" "$ENV_FILE"
    sed -i "s|^HOMEPAGE_PYLOAD_PASSWORD=.*|HOMEPAGE_PYLOAD_PASSWORD=${PYLOAD_PASS}|" "$ENV_FILE"
    sed -i "s|^HOMEPAGE_NPM_EMAIL=.*|HOMEPAGE_NPM_EMAIL=${NPM_EMAIL}|" "$ENV_FILE"
    sed -i "s|^HOMEPAGE_NPM_PASSWORD=.*|HOMEPAGE_NPM_PASSWORD=${NPM_PASS}|" "$ENV_FILE"
    sed -i "s|^HOMEPAGE_ALLOWED_HOSTS=.*|HOMEPAGE_ALLOWED_HOSTS=home.${DOMAIN}|" "$ENV_FILE"

    chmod 600 "$ENV_FILE"
    success ".env créé."

    echo ""
    echo -e "${YELLOW}=== Mots de passe générés (à sauvegarder) ===${NC}"
    echo -e "  RDTClient :          ${BOLD}${RDTCLIENT_PASS}${NC}"
    echo -e "  pyLoad :             ${BOLD}${PYLOAD_PASS}${NC}"
    echo -e "  Nginx Proxy Manager: ${BOLD}${NPM_PASS}${NC} (email: ${NPM_EMAIL})"
    echo ""
}

# --- Création des répertoires -------------------------------------------------
create_directories() {
    # Charger les variables du .env
    set -a; source "$ENV_FILE"; set +a

    info "Création des répertoires de données..."

    local dirs=(
        "${MEDIA_DIR}/movies"
        "${MEDIA_DIR}/tvseries"
        "${MEDIA_DIR}/animes"
        "${DOWNLOADS_DIR}/rdtclient"
        "${DOWNLOADS_DIR}/pyload"
    )

    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chown -R "${PUID}:${PGID}" "$(echo "$dir" | cut -d'/' -f1-4)" 2>/dev/null || true
    done
    success "Répertoires créés."
}

# --- Réseau Docker ------------------------------------------------------------
create_docker_network() {
    if docker network inspect proxy_manager &>/dev/null; then
        success "Réseau Docker 'proxy_manager' existe déjà."
    else
        info "Création du réseau Docker 'proxy_manager'..."
        docker network create proxy_manager
        success "Réseau proxy_manager créé."
    fi
}

# --- Déploiement des stacks ---------------------------------------------------
deploy_stacks() {
    set -a; source "$ENV_FILE"; set +a
    cd "$REPO_DIR"

    info "Démarrage de Nginx Proxy Manager (réseau + reverse proxy)..."
    docker compose -f compose/nginx-proxy-manager/docker-compose.yml up -d
    sleep 3

    info "Démarrage de toutes les stacks..."
    docker compose up -d

    success "Stack complète démarrée."
}

# --- Configuration du cron pour l'updater ------------------------------------
setup_cron() {
    local cron_entry="0 4 * * 0 root ${REPO_DIR}/updater/updater.sh >> /var/log/homelab-updater.log 2>&1"
    local cron_file="/etc/cron.d/homelab-updater"

    if [[ -f "$cron_file" ]]; then
        warn "Cron updater déjà configuré ($cron_file). Ignorer."
        return
    fi

    info "Configuration du cron de mise à jour (dimanche 04h00)..."
    echo "$cron_entry" > "$cron_file"
    chmod 644 "$cron_file"
    success "Cron configuré : $cron_file"
}

# --- Résumé final -------------------------------------------------------------
print_summary() {
    set -a; source "$ENV_FILE"; set +a

    echo ""
    echo -e "${GREEN}${BOLD}=============================================="
    echo -e "  HOMELAB DÉPLOYÉ AVEC SUCCÈS"
    echo -e "==============================================${NC}"
    echo ""
    echo -e "${BOLD}Accès aux services :${NC}"
    echo -e "  Nginx Proxy Manager : http://${SERVER_LAN_IP}:81"
    echo -e "  Plex                : http://${SERVER_LAN_IP}:32400/web"
    echo -e "  Homepage            : https://home.${DOMAIN}  (après config NPM)"
    echo ""
    echo -e "${YELLOW}${BOLD}Étapes suivantes :${NC}"
    echo -e "  1. Configurer Nginx Proxy Manager : http://${SERVER_LAN_IP}:81"
    echo -e "     Email: ${HOMEPAGE_NPM_EMAIL}  •  Mot de passe: ${HOMEPAGE_NPM_PASSWORD}"
    echo -e "  2. Configurer les proxy hosts pour chaque service."
    echo -e "  3. Récupérer les clés API (voir README.md section 'Clés API')."
    echo -e "  4. Mettre à jour .env avec les clés, puis redémarrer homepage :"
    echo -e "     cd ${REPO_DIR} && docker compose restart homepage"
    echo ""
    echo -e "${BOLD}Logs updater :${NC} /var/log/homelab-updater.log"
    echo ""
}

# --- Main ---------------------------------------------------------------------
main() {
    echo -e "${BOLD}"
    echo "   ██╗  ██╗ ██████╗ ███╗   ███╗███████╗██╗      █████╗ ██████╗ "
    echo "   ██║  ██║██╔═══██╗████╗ ████║██╔════╝██║     ██╔══██╗██╔══██╗"
    echo "   ███████║██║   ██║██╔████╔██║█████╗  ██║     ███████║██████╔╝"
    echo "   ██╔══██║██║   ██║██║╚██╔╝██║██╔══╝  ██║     ██╔══██║██╔══██╗"
    echo "   ██║  ██║╚██████╔╝██║ ╚═╝ ██║███████╗███████╗██║  ██║██████╔╝"
    echo "   ╚═╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═════╝ "
    echo -e "${NC}"

    check_root
    check_os
    install_docker
    configure_env
    create_directories
    create_docker_network
    deploy_stacks
    setup_cron
    print_summary
}

main "$@"
