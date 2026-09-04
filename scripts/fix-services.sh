#!/bin/bash
# ============================================================================
# Laravel Server Manager — Servis Yönetimi (fix-services.sh)
# ============================================================================
# Kullanım: sudo bash scripts/fix-services.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🔄 Servis Yönetimi"
    print_banner

    # Mevcut servis durumları
    print_subheader "Mevcut Servis Durumları"

    local services=("nginx" "mysql" "php${PHP_VERSION}-fpm" "supervisor" "redis-server")
    local labels=("Nginx" "MySQL" "PHP-FPM ${PHP_VERSION}" "Supervisor" "Redis")

    for i in "${!services[@]}"; do
        local status
        status=$(check_service_status "${services[$i]}")
        printf "  ${WHITE}%d)${NC} %-25s %b\n" "$((i+1))" "${labels[$i]}" "$status"
    done

    echo ""
    echo -e "  ${WHITE}6)${NC} 🔄 Tüm servisleri yeniden başlat"
    echo -e "  ${WHITE}7)${NC} 🧪 Konfigürasyon testi (Nginx + PHP-FPM)"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    if [[ "$choice" == "0" ]]; then
        return
    fi

    if [[ "$choice" == "6" ]]; then
        print_subheader "Tüm Servisler Yeniden Başlatılıyor"
        for i in "${!services[@]}"; do
            if systemctl is-enabled --quiet "${services[$i]}" 2>/dev/null; then
                restart_service "${services[$i]}"
            fi
        done
        log_action "Tüm servisler yeniden başlatıldı." "INFO"
        print_completion "Servis Yönetimi" "$start_time"
        return
    fi

    if [[ "$choice" == "7" ]]; then
        print_subheader "Konfigürasyon Testi"

        print_step "Nginx konfigürasyon testi..."
        nginx -t 2>&1 | while read -r line; do echo "  $line"; done

        echo ""
        print_step "PHP-FPM konfigürasyon testi..."
        php-fpm${PHP_VERSION} -t 2>&1 | while read -r line; do echo "  $line"; done

        print_completion "Konfigürasyon Testi" "$start_time"
        return
    fi

    # Belirli bir servis seçildi
    local idx=$((choice - 1))
    if [[ $idx -ge 0 && $idx -lt ${#services[@]} ]]; then
        local selected_service="${services[$idx]}"
        local selected_label="${labels[$idx]}"

        echo -e "  ${BOLD}${CYAN}${selected_label} — İşlem Seçin:${NC}"
        echo ""
        echo -e "  ${WHITE}a)${NC} Yeniden Başlat"
        echo -e "  ${WHITE}b)${NC} Durdur"
        echo -e "  ${WHITE}c)${NC} Başlat"
        echo -e "  ${WHITE}d)${NC} Durum Göster"
        echo -ne "  ${CYAN}Seçiminiz${NC}: "
        read -r action

        echo ""
        case "$action" in
            a) try_run "${selected_label} yeniden başlatılıyor" "systemctl restart ${selected_service}" ;;
            b) try_run "${selected_label} durduruluyor" "systemctl stop ${selected_service}" ;;
            c) try_run "${selected_label} başlatılıyor" "systemctl start ${selected_service}" ;;
            d) systemctl status "${selected_service}" 2>&1 | head -20 | while read -r line; do echo "  $line"; done ;;
            *) print_warning "Geçersiz seçim!" ;;
        esac

        log_action "${selected_label} servisi üzerinde işlem yapıldı (${action})." "INFO"
    else
        print_warning "Geçersiz seçim!"
    fi

    print_completion "Servis Yönetimi" "$start_time"
}

main "$@"
