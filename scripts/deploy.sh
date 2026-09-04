#!/bin/bash
# ============================================================================
# Laravel Server Manager — Akıllı Deploy / Güncelleme (deploy.sh)
# ============================================================================
# Kullanım: bash scripts/deploy.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Config yükle
load_config

# Error trap
enable_error_trap

# ============================================================================
# FONKSİYONLAR
# ============================================================================

# Deploy öncesi kontroller
pre_deploy_checks() {
    print_subheader "Deploy Öncesi Kontroller"

    # Proje dizini kontrolü
    if [[ ! -d "$APP_DIR" ]]; then
        print_error "Proje dizini bulunamadı: ${APP_DIR}"
        exit 1
    fi

    # Git repo kontrolü
    if [[ ! -d "${APP_DIR}/.git" ]]; then
        print_error "Proje dizini bir Git repository değil!"
        exit 1
    fi

    # Composer kontrolü
    if ! command -v composer &> /dev/null; then
        print_error "Composer bulunamadı!"
        exit 1
    fi

    # PHP kontrolü
    if ! command -v php &> /dev/null; then
        print_error "PHP bulunamadı!"
        exit 1
    fi

    print_success "Tüm kontroller başarılı."
}

# Git pull işlemi
pull_latest_code() {
    print_subheader "Kod Güncelleniyor"

    cd "$APP_DIR"

    # Remote URL'yi güncelle (token değişmiş olabilir)
    local repo_url
    if [[ "$REPO_VISIBILITY" == "private" && -n "$GITHUB_TOKEN" ]]; then
        repo_url="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
    else
        repo_url="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
    fi

    git remote set-url origin "$repo_url" 2>/dev/null || true

    # Mevcut branch kontrolü
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    print_info "Mevcut branch: ${current_branch}"

    if [[ "$current_branch" != "$GITHUB_BRANCH" ]]; then
        print_warning "Hedef branch (${GITHUB_BRANCH}) farklı. Geçiş yapılıyor..."
        git checkout "$GITHUB_BRANCH" 2>/dev/null || true
    fi

    # Son commit bilgisi (önceki)
    local prev_commit
    prev_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    print_info "Mevcut commit: ${prev_commit}"

    # Git pull
    try_run_verbose "Son değişiklikler çekiliyor" "git pull origin ${GITHUB_BRANCH}"

    # Son commit bilgisi (sonraki)
    local new_commit
    new_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    if [[ "$prev_commit" == "$new_commit" ]]; then
        print_info "Zaten güncel — değişiklik yok."
    else
        print_success "Güncellendi: ${prev_commit} → ${new_commit}"
    fi

    cd - > /dev/null
}

# Composer bağımlılıklarını güncelle
update_dependencies() {
    print_subheader "Bağımlılıklar Güncelleniyor"

    cd "$APP_DIR"
    try_run_verbose "Composer install çalıştırılıyor" "composer install --no-dev --optimize-autoloader --no-interaction 2>&1"
    cd - > /dev/null
}

# Laravel migration
run_migrations() {
    print_subheader "Veritabanı Migration"

    cd "$APP_DIR"
    try_run_verbose "Migration çalıştırılıyor" "php artisan migrate --force 2>&1"
    cd - > /dev/null
}

# Front-end asset derleme (Vite / Mix)
build_assets() {
    if [[ -f "${APP_DIR}/package.json" ]]; then
        print_subheader "Front-end Asset Derleme (Vite)"
        cd "$APP_DIR"

        if ! command -v npm &> /dev/null; then
            print_warning "NPM bulunamadı! Node.js ve NPM kuruluyor..."
            local sudo_cmd=""
            [[ $EUID -ne 0 ]] && sudo_cmd="sudo"
            if curl -fsSL https://deb.nodesource.com/setup_20.x | $sudo_cmd bash - > /dev/null 2>&1; then
                $sudo_cmd apt-get install -y nodejs > /dev/null 2>&1 || true
            else
                $sudo_cmd apt-get update -y > /dev/null 2>&1 || true
                $sudo_cmd apt-get install -y nodejs npm > /dev/null 2>&1 || true
            fi
        fi

        if command -v npm &> /dev/null; then
            try_run_verbose "NPM bağımlılıkları yükleniyor" "npm install --no-audit 2>&1"
            try_run_verbose "Asset'ler derleniyor (npm run build)" "npm run build 2>&1"
        else
            print_error "NPM kurulamadı. Asset derleme atlandı."
        fi
        cd - > /dev/null
    fi
}

# Cache temizle ve yeniden oluştur
refresh_cache() {
    print_subheader "Cache Yenileniyor"

    cd "$APP_DIR"

    # Önce temizle
    try_run "Config cache temizleniyor" "php artisan config:clear"
    try_run "Route cache temizleniyor" "php artisan route:clear"
    try_run "View cache temizleniyor" "php artisan view:clear"
    try_run "Event cache temizleniyor" "php artisan event:clear"

    # Yeniden oluştur
    try_run "Config cache oluşturuluyor" "php artisan config:cache"
    try_run "Route cache oluşturuluyor" "php artisan route:cache"
    try_run "View cache oluşturuluyor" "php artisan view:cache"
    try_run "Event cache oluşturuluyor" "php artisan event:cache"

    cd - > /dev/null
}

# Dosya izinlerini düzelt
fix_permissions() {
    print_subheader "Dosya İzinleri Düzeltiliyor"

    local deploy_user="${SUDO_USER:-$USER}"
    if [[ "$deploy_user" == "root" || -z "$deploy_user" ]]; then
        deploy_user=$(stat -c '%U' "$SCRIPT_DIR" 2>/dev/null || echo "")
        if [[ -z "$deploy_user" || "$deploy_user" == "root" ]]; then
            deploy_user=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd || echo "www-data")
        fi
    fi

    if [[ "$deploy_user" != "www-data" && "$deploy_user" != "root" ]]; then
        usermod -aG www-data "$deploy_user" 2>/dev/null || true
    fi

    chown -R "${deploy_user}:www-data" "$APP_DIR"
    find "$APP_DIR" -type f -exec chmod 664 {} \;
    find "$APP_DIR" -type d -exec chmod 775 {} \;
    chmod -R g+s "$APP_DIR"
    chmod -R 775 "${APP_DIR}/storage" "${APP_DIR}/bootstrap/cache"
    chmod 660 "${APP_DIR}/.env" 2>/dev/null || true
    [[ -f "${APP_DIR}/artisan" ]] && chmod +x "${APP_DIR}/artisan"

    print_success "Dosya izinleri düzeltildi (${deploy_user}:www-data)."
}

# Queue worker'ları yeniden başlat
restart_workers() {
    print_subheader "Queue Worker Yeniden Başlatılıyor"

    try_run "Queue yeniden başlatılıyor" "php ${APP_DIR}/artisan queue:restart"

    if command -v supervisorctl &> /dev/null; then
        try_run "Supervisor güncelleniyor" "supervisorctl reread && supervisorctl update"
        try_run "Worker'lar yeniden başlatılıyor" "supervisorctl restart ${APP_NAME}-worker:*"
    fi
}

# ============================================================================
# ANA AKIŞ
# ============================================================================

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🚀 Deploy / Güncelleme"
    print_banner

    # Onay al
    print_info "Proje: ${BOLD}${APP_NAME}${NC}"
    print_info "Dizin: ${APP_DIR}"
    print_info "Branch: ${GITHUB_BRANCH}"
    echo ""

    if ! confirm_action "Deploy işlemine başlamak istiyor musunuz?"; then
        print_warning "Deploy iptal edildi."
        return
    fi

    echo ""

    # Deploy öncesi kontroller
    pre_deploy_checks

    # Maintenance mode
    print_subheader "Bakım Modu Açılıyor"
    try_run "Bakım modu açılıyor" "php ${APP_DIR}/artisan down --render='errors::503' --retry=60"

    # Deploy adımları
    pull_latest_code
    update_dependencies
    run_migrations
    build_assets
    refresh_cache
    fix_permissions
    restart_workers

    # Maintenance mode kapat
    print_subheader "Bakım Modu Kapatılıyor"
    try_run "Bakım modu kapatılıyor" "php ${APP_DIR}/artisan up"

    # Deploy timestamp güncelle
    update_config_value "DEPLOY_TIMESTAMP" "$(timestamp)"

    # Log kaydet
    log_action "Deploy tamamlandı. Proje: ${APP_NAME}" "SUCCESS"

    # Sonuç raporu
    echo ""
    echo -e "  ${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "  ${GREEN}║  ${BOLD}${WHITE}✅ DEPLOY BAŞARIYLA TAMAMLANDI!${NC}${GREEN}                ║${NC}"
    echo -e "  ${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""

    print_completion "Deploy" "$start_time"
}

main "$@"
