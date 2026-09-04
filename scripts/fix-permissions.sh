#!/bin/bash
# ============================================================================
# Laravel Server Manager — Dosya İzinlerini Düzelt (fix-permissions.sh)
# ============================================================================
# Kullanım: sudo bash scripts/fix-permissions.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

# ============================================================================
# ANA AKIŞ
# ============================================================================

main() {
    local start_time
    start_time=$(date +%s)

    print_header "📁 Dosya İzinlerini Düzelt"
    print_banner

    # Dizin kontrolü
    if [[ ! -d "$APP_DIR" ]]; then
        print_error "Proje dizini bulunamadı: ${APP_DIR}"
        exit 1
    fi

    print_info "Proje dizini: ${APP_DIR}"
    echo ""

    if ! confirm_action "Dosya izinleri düzeltilecek. Devam edilsin mi?"; then
        print_warning "İşlem iptal edildi."
        return
    fi

    echo ""

    # Deploy kullanıcısını belirle (sudo çalıştıran asıl kullanıcı veya dizin sahibi)
    local deploy_user="${SUDO_USER:-$USER}"
    if [[ "$deploy_user" == "root" || -z "$deploy_user" ]]; then
        deploy_user=$(stat -c '%U' "$SCRIPT_DIR" 2>/dev/null || echo "")
        if [[ -z "$deploy_user" || "$deploy_user" == "root" ]]; then
            deploy_user=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1; exit}' /etc/passwd || echo "www-data")
        fi
    fi

    # Kullanıcıyı www-data grubuna ekle
    if [[ "$deploy_user" != "www-data" && "$deploy_user" != "root" ]]; then
        usermod -aG www-data "$deploy_user" 2>/dev/null || true
    fi

    # Sahiplik: deploy_user:www-data
    try_run "Sahiplik ayarlanıyor (${deploy_user}:www-data)" "chown -R ${deploy_user}:www-data ${APP_DIR}"

    # Dizin izinleri: 775 (Sahip ve www-data grubu yazabilir)
    try_run "Dizin izinleri ayarlanıyor (775)" "find ${APP_DIR} -type d -exec chmod 775 {} \\;"

    # Dosya izinleri: 664 (Sahip ve www-data grubu yazabilir)
    try_run "Dosya izinleri ayarlanıyor (664)" "find ${APP_DIR} -type f -exec chmod 664 {} \\;"

    # SGID biti: Yeni oluşturulacak tüm dosya/klasörler otomatik www-data grubuna ait olur
    try_run "SGID ayarlanıyor (yeni dosyalar www-data grubunu miras alır)" "chmod -R g+s ${APP_DIR}"

    # Storage ve bootstrap/cache: 775
    try_run "storage/ izinleri ayarlanıyor (775)" "chmod -R 775 ${APP_DIR}/storage"
    try_run "bootstrap/cache/ izinleri ayarlanıyor (775)" "chmod -R 775 ${APP_DIR}/bootstrap/cache"

    # .env: 660 (Sahip ve www-data okur/yazar, diğerleri okuyamaz)
    if [[ -f "${APP_DIR}/.env" ]]; then
        try_run ".env izinleri ayarlanıyor (660)" "chmod 660 ${APP_DIR}/.env"
    fi

    # Artisan çalıştırılabilir
    if [[ -f "${APP_DIR}/artisan" ]]; then
        try_run "artisan çalıştırılabilir yapılıyor" "chmod +x ${APP_DIR}/artisan"
    fi

    # Node_modules/.bin ve vendor/bin çalıştırılabilir
    if [[ -d "${APP_DIR}/node_modules/.bin" ]]; then
        try_run "node_modules/.bin çalıştırılabilir yapılıyor" "chmod -R +x ${APP_DIR}/node_modules/.bin"
    fi
    if [[ -d "${APP_DIR}/vendor/bin" ]]; then
        try_run "vendor/bin çalıştırılabilir yapılıyor" "chmod -R +x ${APP_DIR}/vendor/bin"
    fi

    # Log kaydet
    log_action "Dosya izinleri düzeltildi. Proje: ${APP_NAME}" "INFO"

    print_completion "Dosya İzinleri" "$start_time"
}

main "$@"
