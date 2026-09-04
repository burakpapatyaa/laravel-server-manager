#!/bin/bash
# ============================================================================
# Laravel Server Manager — Laravel Cache Temizle / Yenile (fix-laravel-cache.sh)
# ============================================================================
# Kullanım: bash scripts/fix-laravel-cache.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    if [[ ! -d "$APP_DIR" ]]; then
        print_error "Proje dizini bulunamadı: ${APP_DIR}"
        exit 1
    fi

    while true; do
        clear
        print_header "Laravel Cache Yönetimi"
        print_banner

        cd "$APP_DIR"

        echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
        echo ""
        echo -e "  ${WHITE}1)${NC} Tüm cache'leri temizle"
        echo -e "  ${WHITE}2)${NC} Tüm cache'leri temizle ve yeniden oluştur"
        echo -e "  ${WHITE}3)${NC} Sadece config cache"
        echo -e "  ${WHITE}4)${NC} Sadece route cache"
        echo -e "  ${WHITE}5)${NC} Sadece view cache"
        echo -e "  ${WHITE}6)${NC} Sadece event cache"
        echo -e "  ${WHITE}7)${NC} Application cache temizle"
        echo -e "  ${WHITE}8)${NC} Composer dump-autoload"
        echo -e "  ${WHITE}9)${NC} OPcache sıfırla"
        echo -e "  ${WHITE}0)${NC} ← Geri Dön"

        local choice
        choice=$(read_menu_choice)

        [[ -z "$choice" ]] && continue

        if [[ "$choice" == "0" || "$choice" == "q" || "$choice" == "Q" ]]; then
            break
        fi

        echo ""

        case "$choice" in
            1)
                print_subheader "Tüm Cache Temizleniyor"
                try_run "Config cache temizleniyor" "php artisan config:clear"
                try_run "Route cache temizleniyor" "php artisan route:clear"
                try_run "View cache temizleniyor" "php artisan view:clear"
                try_run "Event cache temizleniyor" "php artisan event:clear"
                try_run "Application cache temizleniyor" "php artisan cache:clear"
                ;;
            2)
                print_subheader "Cache Temizlenip Yeniden Oluşturuluyor"
                try_run "Config cache temizleniyor" "php artisan config:clear"
                try_run "Route cache temizleniyor" "php artisan route:clear"
                try_run "View cache temizleniyor" "php artisan view:clear"
                try_run "Event cache temizleniyor" "php artisan event:clear"
                try_run "Application cache temizleniyor" "php artisan cache:clear"

                echo ""
                print_step "Cache yeniden oluşturuluyor..."
                try_run "Config cache oluşturuluyor" "php artisan config:cache"
                try_run "Route cache oluşturuluyor" "php artisan route:cache"
                try_run "View cache oluşturuluyor" "php artisan view:cache"
                try_run "Event cache oluşturuluyor" "php artisan event:cache"
                ;;
            3)
                try_run "Config cache temizleniyor" "php artisan config:clear"
                if confirm_action "Yeniden oluşturulsun mu?"; then
                    try_run "Config cache oluşturuluyor" "php artisan config:cache"
                fi
                ;;
            4)
                try_run "Route cache temizleniyor" "php artisan route:clear"
                if confirm_action "Yeniden oluşturulsun mu?"; then
                    try_run "Route cache oluşturuluyor" "php artisan route:cache"
                fi
                ;;
            5)
                try_run "View cache temizleniyor" "php artisan view:clear"
                if confirm_action "Yeniden oluşturulsun mu?"; then
                    try_run "View cache oluşturuluyor" "php artisan view:cache"
                fi
                ;;
            6)
                try_run "Event cache temizleniyor" "php artisan event:clear"
                if confirm_action "Yeniden oluşturulsun mu?"; then
                    try_run "Event cache oluşturuluyor" "php artisan event:cache"
                fi
                ;;
            7)
                try_run "Application cache temizleniyor" "php artisan cache:clear"
                ;;
            8)
                try_run "Composer autoload yeniden oluşturuluyor" "composer dump-autoload --optimize"
                ;;
            9)
                print_step "OPcache sıfırlanıyor..."
                php -r "if(function_exists('opcache_reset')) { opcache_reset(); echo 'OPcache sıfırlandı.'; } else { echo 'OPcache aktif değil.'; }" 2>/dev/null
                echo ""
                ;;
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                continue
                ;;
        esac

        log_action "Cache işlemi yapıldı (Seçim: ${choice}). Proje: ${APP_NAME}" "INFO"
        press_enter_to_continue
    done

    cd - > /dev/null 2>&1 || true
    print_completion "Cache Yönetimi" "$start_time"
}

main "$@"
