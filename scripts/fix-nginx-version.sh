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

# FastCGI SCRIPT_FILENAME hatasını otomatik düzelt
fix_fastcgi_param_error() {
    print_subheader "FastCGI SCRIPT_FILENAME Hatası Onarılıyor"

    local fixed=0
    local search_dirs=("/etc/nginx/sites-available" "/etc/nginx/conf.d")

    for dir in "${search_dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        for conf in "$dir"/*; do
            [[ -f "$conf" ]] || continue
            # fastcgi_param SCRIPT_FILENAME içeren dosyaları tara
            if grep -q "fastcgi_param[[:space:]]*SCRIPT_FILENAME" "$conf" 2>/dev/null; then
                # SCRIPT_FILENAME sonrasında değer eksikse veya bozuksa
                if grep -E "fastcgi_param[[:space:]]+SCRIPT_FILENAME[[:space:]]*;" "$conf" 2>/dev/null || \
                   ! grep -q 'fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;' "$conf" 2>/dev/null; then
                    print_step "Düzeltiliyor: ${conf}..."
                    cp "$conf" "${conf}.bak.$(date +%s)" 2>/dev/null || true
                    sed -i 's|fastcgi_param[[:space:]]*SCRIPT_FILENAME.*;|fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;|' "$conf"
                    fixed=$((fixed + 1))
                fi
            fi
        done
    done

    # Eğer APP_NAME vhost'u varsa ve kontrol edilmediyse doğrudan güncelle
    local app_vhost="/etc/nginx/sites-available/${APP_NAME}"
    if [[ -f "$app_vhost" ]]; then
        sed -i 's|fastcgi_param[[:space:]]*SCRIPT_FILENAME.*;|fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;|' "$app_vhost"
    fi

    if [[ $fixed -gt 0 ]]; then
        print_success "${fixed} adet vhost konfigürasyonu onarıldı."
    else
        print_info "Vhost dosyaları kontrol edildi ve Laravel FastCGI standardına güncellendi."
    fi

    echo ""
    print_step "Nginx konfigürasyonu test ediliyor (nginx -t)..."
    if nginx -t 2>&1 | while read -r line; do echo "  $line"; done; then
        print_success "Nginx konfigürasyon testi başarılı!"
        echo ""
        if confirm_action "Nginx servisini yeniden yüklemek (reload) istiyor musunuz?"; then
            try_run "Nginx yeniden yükleniyor" "systemctl reload nginx"
        fi
    else
        print_error "Nginx konfigürasyonunda başka bir hata mevcut. Lütfen yukarıdaki çıktıyı inceleyin."
    fi
}

main() {
    local start_time
    start_time=$(date +%s)

    while true; do
        clear
        print_header "Nginx Yönetimi"
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
        echo -e "  ${WHITE}7)${NC} Vhost konfigürasyonunu görüntüle / düzenle"
        echo -e "  ${WHITE}8)${NC} FastCGI (SCRIPT_FILENAME) hatasını otomatik onar"
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
                print_subheader "Nginx Konfigürasyon Testi"
                local test_output
                test_output=$(nginx -t 2>&1)
                echo "$test_output" | while read -r line; do echo "  $line"; done

                if echo "$test_output" | grep -q "fastcgi_param"; then
                    echo ""
                    print_warning "FastCGI parametre hatası tespit edildi!"
                    print_info "Vhost dosyasındaki 'fastcgi_param SCRIPT_FILENAME' satırı boş veya hatalı."
                    if confirm_action "Bu hatayı şimdi otomatik onarmak istiyor musunuz?"; then
                        fix_fastcgi_param_error
                    fi
                fi
                ;;
            2)
                if confirm_action "Nginx yeniden başlatılacak. Devam?"; then
                    local test_output
                    test_output=$(nginx -t 2>&1)
                    if echo "$test_output" | grep -q "successful"; then
                        restart_service "nginx"
                    else
                        print_error "Konfigürasyon hatası var! Önce düzeltin."
                        echo "$test_output" | while read -r line; do echo "  $line"; done
                        if echo "$test_output" | grep -q "fastcgi_param"; then
                            echo ""
                            print_warning "FastCGI parametre hatası tespit edildi!"
                            if confirm_action "Bu hatayı şimdi otomatik onarmak istiyor musunuz?"; then
                                fix_fastcgi_param_error
                            fi
                        fi
                    fi
                fi
                ;;
            3)
                local test_output
                test_output=$(nginx -t 2>&1)
                if echo "$test_output" | grep -q "successful"; then
                    try_run "Nginx yeniden yükleniyor" "systemctl reload nginx"
                else
                    print_error "Konfigürasyon hatası var!"
                    echo "$test_output" | while read -r line; do echo "  $line"; done
                    if echo "$test_output" | grep -q "fastcgi_param"; then
                        echo ""
                        print_warning "FastCGI parametre hatası tespit edildi!"
                        if confirm_action "Bu hatayı şimdi otomatik onarmak istiyor musunuz?"; then
                            fix_fastcgi_param_error
                        fi
                    fi
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
                if [[ ! -f "$vhost_file" ]]; then
                    # Mevcut vhost'u bulmaya çalış
                    vhost_file=$(ls /etc/nginx/sites-available/* 2>/dev/null | head -1 || echo "")
                fi

                if [[ -f "$vhost_file" ]]; then
                    print_subheader "Vhost Konfigürasyonu (${vhost_file})"
                    nl -ba "$vhost_file" | head -40 | while read -r line; do echo "  $line"; done
                    echo ""
                    print_info "Düzenlemek için: ${BOLD}sudo nano ${vhost_file}${NC}"
                else
                    print_warning "Vhost dosyası bulunamadı!"
                fi
                ;;
            8)
                fix_fastcgi_param_error
                ;;
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                continue
                ;;
        esac

        log_action "Nginx yönetimi (Seçim: ${choice})." "INFO"
        press_enter_to_continue
    done

    print_completion "Nginx Yönetimi" "$start_time"
}

main "$@"
