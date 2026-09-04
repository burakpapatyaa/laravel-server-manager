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

    # Sahiplik
    try_run "Sahiplik ayarlanıyor (www-data:www-data)" "chown -R www-data:www-data ${APP_DIR}"

    # Dosya izinleri: 644
    try_run "Dosya izinleri ayarlanıyor (644)" "find ${APP_DIR} -type f -exec chmod 644 {} \\;"

    # Dizin izinleri: 755
    try_run "Dizin izinleri ayarlanıyor (755)" "find ${APP_DIR} -type d -exec chmod 755 {} \\;"

    # Storage ve bootstrap/cache: 775
    try_run "storage/ izinleri ayarlanıyor (775)" "chmod -R 775 ${APP_DIR}/storage"
    try_run "bootstrap/cache/ izinleri ayarlanıyor (775)" "chmod -R 775 ${APP_DIR}/bootstrap/cache"

    # .env: 640
    if [[ -f "${APP_DIR}/.env" ]]; then
        try_run ".env izinleri ayarlanıyor (640)" "chmod 640 ${APP_DIR}/.env"
    fi

    # Artisan çalıştırılabilir
    if [[ -f "${APP_DIR}/artisan" ]]; then
        try_run "artisan çalıştırılabilir yapılıyor" "chmod +x ${APP_DIR}/artisan"
    fi

    # Log kaydet
    log_action "Dosya izinleri düzeltildi. Proje: ${APP_NAME}" "INFO"

    print_completion "Dosya İzinleri" "$start_time"
}

main "$@"
