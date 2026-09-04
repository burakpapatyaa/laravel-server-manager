#!/bin/bash
# ============================================================================
# Laravel Server Manager — Storage Symlink Onar (fix-storage.sh)
# ============================================================================
# Kullanım: bash scripts/fix-storage.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🔗 Storage Symlink Onarımı"
    print_banner

    if [[ ! -d "$APP_DIR" ]]; then
        print_error "Proje dizini bulunamadı: ${APP_DIR}"
        exit 1
    fi

    cd "$APP_DIR"

    # Storage dizin yapısını kontrol et
    print_subheader "Dizin Kontrolü"

    local dirs=(
        "storage/app"
        "storage/app/public"
        "storage/framework"
        "storage/framework/cache"
        "storage/framework/cache/data"
        "storage/framework/sessions"
        "storage/framework/testing"
        "storage/framework/views"
        "storage/logs"
        "bootstrap/cache"
    )

    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_table_row "$dir" "✅ Mevcut" "$GREEN"
        else
            mkdir -p "$dir"
            print_table_row "$dir" "📁 Oluşturuldu" "$YELLOW"
        fi
    done

    # .gitignore dosyalarını kontrol et
    echo ""
    print_subheader "Gitignore Kontrolü"

    local gitignore_dirs=("storage/app" "storage/framework/cache" "storage/framework/sessions" "storage/framework/views" "storage/logs")

    for gdir in "${gitignore_dirs[@]}"; do
        local gitignore="${gdir}/.gitignore"
        if [[ ! -f "$gitignore" ]]; then
            echo -e "*\n!.gitignore" > "$gitignore"
            print_table_row "$gitignore" "📄 Oluşturuldu" "$YELLOW"
        else
            print_table_row "$gitignore" "✅ Mevcut" "$GREEN"
        fi
    done

    # Storage link kontrolü ve onarımı
    echo ""
    print_subheader "Storage Link"

    if [[ -L "public/storage" ]]; then
        local link_target
        link_target=$(readlink -f "public/storage" 2>/dev/null || echo "Bilinmiyor")
        print_table_row "Symlink:" "✅ Mevcut" "$GREEN"
        print_table_row "Hedef:" "$link_target" "$GRAY"

        if confirm_action "Symlink'i yeniden oluşturmak ister misiniz?"; then
            rm -f "public/storage"
            try_run "Storage link yeniden oluşturuluyor" "php artisan storage:link"
        fi
    else
        print_table_row "Symlink:" "❌ Eksik" "$RED"
        try_run "Storage link oluşturuluyor" "php artisan storage:link"
    fi

    # İzinleri düzelt
    echo ""
    print_subheader "İzinler"
    try_run "Storage izinleri düzeltiliyor" "chmod -R 775 storage bootstrap/cache"
    try_run "Sahiplik ayarlanıyor" "chown -R www-data:www-data storage bootstrap/cache"

    log_action "Storage onarıldı. Proje: ${APP_NAME}" "INFO"
    cd - > /dev/null

    print_completion "Storage Onarımı" "$start_time"
}

main "$@"
