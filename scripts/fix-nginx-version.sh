#!/bin/bash
# ============================================================================
# Laravel Server Manager — Nginx Yönetimi (fix-nginx-version.sh)
# ============================================================================
# Kullanım: sudo bash scripts/fix-nginx-version.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🌐 Nginx Yönetimi"
    print_banner

    # Nginx bilgisi
    print_subheader "Nginx Bilgisi"

    local nginx_version
    nginx_version=$(nginx -v 2>&1 | awk -F'/' '{print $2}' || echo "Bilinmiyor")
    local nginx_status
    nginx_status=$(check_service_status "nginx")

    print_table_row "Nginx Sürümü:" "$nginx_version" "$WHITE"
    printf "  %-25s %b\n" "Nginx Durumu:" "$nginx_status"

    echo ""
    echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} Konfigürasyon testi (nginx -t)"
    echo -e "  ${WHITE}2)${NC} Nginx'i yeniden başlat"
    echo -e "  ${WHITE}3)${NC} Nginx'i yeniden yükle (reload)"
    echo -e "  ${WHITE}4)${NC} Vhost konfigürasyonlarını listele"
    echo -e "  ${WHITE}5)${NC} Error log'u görüntüle (son 30 satır)"
    echo -e "  ${WHITE}6)${NC} Access log'u görüntüle (son 30 satır)"
    echo -e "  ${WHITE}7)${NC} Vhost konfigürasyonunu düzenle"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    case "$choice" in
        1)
            print_subheader "Nginx Konfigürasyon Testi"
            nginx -t 2>&1 | while read -r line; do echo "  $line"; done
            ;;
        2)
            if confirm_action "Nginx yeniden başlatılacak. Devam?"; then
                # Önce test et
                if nginx -t 2>/dev/null; then
                    restart_service "nginx"
                else
                    print_error "Konfigürasyon hatası var! Önce düzeltin."
                    nginx -t 2>&1 | while read -r line; do echo "  $line"; done
                fi
            fi
            ;;
        3)
            if nginx -t 2>/dev/null; then
                try_run "Nginx yeniden yükleniyor" "systemctl reload nginx"
            else
                print_error "Konfigürasyon hatası var!"
                nginx -t 2>&1 | while read -r line; do echo "  $line"; done
            fi
            ;;
        4)
            print_subheader "Etkin Vhost'lar (sites-enabled)"
            ls -la /etc/nginx/sites-enabled/ 2>/dev/null | tail -n +2 | while read -r line; do echo "  $line"; done

            echo ""
            print_subheader "Mevcut Vhost'lar (sites-available)"
            ls -la /etc/nginx/sites-available/ 2>/dev/null | tail -n +2 | while read -r line; do echo "  $line"; done
            ;;
        5)
            print_subheader "Nginx Error Log (Son 30 Satır)"
            local error_log="/var/log/nginx/error.log"
            if [[ -f "$error_log" ]]; then
                tail -30 "$error_log" | while read -r line; do echo "  $line"; done
            else
                print_warning "Error log bulunamadı: ${error_log}"
            fi
            ;;
        6)
            print_subheader "Nginx Access Log (Son 30 Satır)"
            local access_log="/var/log/nginx/access.log"
            if [[ -f "$access_log" ]]; then
                tail -30 "$access_log" | while read -r line; do echo "  $line"; done
            else
                print_warning "Access log bulunamadı: ${access_log}"
            fi
            ;;
        7)
            local vhost_file="/etc/nginx/sites-available/${APP_NAME}"
            if [[ -f "$vhost_file" ]]; then
                print_subheader "Mevcut Vhost Konfigürasyonu"
                cat "$vhost_file" | while read -r line; do echo "  $line"; done
                echo ""
                print_info "Düzenlemek için: ${BOLD}nano ${vhost_file}${NC}"
            else
                print_warning "Vhost dosyası bulunamadı: ${vhost_file}"
            fi
            ;;
        0)
            return
            ;;
    esac

    log_action "Nginx yönetimi (Seçim: ${choice})." "INFO"

    print_completion "Nginx Yönetimi" "$start_time"
}

main "$@"
