#!/bin/bash
# ============================================================================
# Laravel Server Manager — Log Görüntüleyici & Hata Teşhis (view-logs.sh)
# ============================================================================
# Kullanım: bash scripts/view-logs.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

# Laravel log dosyasını bul
get_laravel_log() {
    local log_file="${APP_DIR}/storage/logs/laravel.log"
    echo "$log_file"
}

# Hızlı hata özeti
show_quick_error_summary() {
    local log_file
    log_file=$(get_laravel_log)

    print_subheader "Son Laravel Hatası (Son 25 Satır)"

    if [[ -f "$log_file" && -s "$log_file" ]]; then
        echo -e "  ${GRAY}Log dosyası: ${log_file} ($(du -h "$log_file" | awk '{print $1}'))${NC}"
        echo ""
        tail -n 25 "$log_file" | while read -r line; do
            if echo "$line" | grep -qE "ERROR|CRITICAL|EMERGENCY"; then
                echo -e "  ${RED}${line}${NC}"
            elif echo "$line" | grep -qE "WARNING|ALERT"; then
                echo -e "  ${YELLOW}${line}${NC}"
            elif echo "$line" | grep -qE "^\\[[0-9]{4}-"; then
                echo -e "  ${CYAN}${line}${NC}"
            else
                echo -e "  ${GRAY}${line}${NC}"
            fi
        done
    else
        print_info "Laravel log dosyası boş veya henüz oluşturulmamış."
    fi
}

# APP_DEBUG değiştirici
toggle_app_debug() {
    local env_file="${APP_DIR}/.env"
    if [[ ! -f "$env_file" ]]; then
        print_error ".env dosyası bulunamadı: ${env_file}"
        return 1
    fi

    local current_debug
    current_debug=$(grep "^APP_DEBUG=" "$env_file" | cut -d'=' -f2 | tr -d ' "' || echo "false")

    if [[ "$current_debug" == "true" ]]; then
        sed -i 's/^APP_DEBUG=.*/APP_DEBUG=false/' "$env_file"
        print_step "Config önbelleği temizleniyor..."
        (cd "$APP_DIR" && php artisan config:clear >/dev/null 2>&1 || true)
        print_success "APP_DEBUG=false olarak ayarlandı (Güvenli / Production Modu)."
    else
        sed -i 's/^APP_DEBUG=.*/APP_DEBUG=true/' "$env_file"
        print_step "Config önbelleği temizleniyor..."
        (cd "$APP_DIR" && php artisan config:clear >/dev/null 2>&1 || true)
        print_warning "APP_DEBUG=true olarak ayarlandı (Hata Ayıklama Modu)!"
        print_info "Şimdi tarayıcınızda sayfayı yenileyerek hatanın tam detayını (dosya adı ve satır numarası) görebilirsiniz."
    fi
}

# Veritabanı bağlantı testi
test_database_connection() {
    print_subheader "Veritabanı ve Migration Durumu Test Ediliyor"
    
    if [[ -d "$APP_DIR" && -f "$APP_DIR/artisan" ]]; then
        print_step "php artisan db:monitor / migrate:status çalıştırılıyor..."
        cd "$APP_DIR"
        
        if php artisan migrate:status 2>&1 | head -n 30 | while read -r line; do echo "  $line"; done; then
            print_success "Veritabanı bağlantısı ve migration durumu normal."
        else
            print_error "Veritabanı bağlantısında veya migration'da hata var!"
            print_info "Olası nedenler: DB şifresi yanlış, kullanıcı yetkisi eksik veya tablolar oluşturulmamış."
        fi
        cd - > /dev/null
    else
        print_error "Proje dizini veya artisan bulunamadı."
    fi
}

# Vite / Build kontrolü
check_vite_assets() {
    print_subheader "Vite / Front-end Asset Kontrolü"

    local manifest="${APP_DIR}/public/build/manifest.json"
    if [[ -f "$manifest" ]]; then
        print_success "Vite manifest dosyası mevcut: ${manifest}"
    else
        print_warning "Vite manifest dosyası BULUNAMADI: ${manifest}"
        print_info "Eğer projenizde @vite kullanılıyorsa, bu durum '500 Server Error' hatasına yol açar!"
        
        if [[ -f "${APP_DIR}/package.json" ]]; then
            echo ""
            if confirm_action "npm install ve npm run build çalıştırmak istiyor musunuz?" "e"; then
                if ! command -v npm &>/dev/null; then
                    print_step "Node.js ve NPM kuruluyor..."
                    if [[ $EUID -ne 0 ]]; then
                        sudo apt-get update -y && sudo apt-get install -y nodejs npm
                    else
                        apt-get update -y && apt-get install -y nodejs npm
                    fi
                fi
                
                print_step "npm install çalıştırılıyor..."
                (cd "$APP_DIR" && npm install)
                print_step "npm run build çalıştırılıyor..."
                (cd "$APP_DIR" && npm run build)
                
                if [[ -f "$manifest" ]]; then
                    print_success "Asset'ler başarıyla derlendi! Manifest oluşturuldu."
                    chown -R www-data:www-data "${APP_DIR}/public/build" 2>/dev/null || true
                else
                    print_error "Asset derleme tamamlanamadı."
                fi
            fi
        else
            print_info "Projede package.json bulunamadı."
        fi
    fi
}

main() {
    while true; do
        clear
        print_header "Log Görüntüleyici & Hata Teşhis"
        print_banner

        local env_file="${APP_DIR}/.env"
        local current_debug="bilinmiyor"
        if [[ -f "$env_file" ]]; then
            current_debug=$(grep "^APP_DEBUG=" "$env_file" | cut -d'=' -f2 | tr -d ' "' || echo "false")
        fi

        echo -e "  ${GRAY}Aktif Proje:${NC} ${WHITE}${APP_NAME}${NC}  ${GRAY}│${NC}  ${GRAY}APP_DEBUG:${NC} $([[ "$current_debug" == "true" ]] && echo -e "${RED}${BOLD}true (Açık)${NC}" || echo -e "${GREEN}false (Kapalı)${NC}")"
        echo ""

        show_quick_error_summary

        echo ""
        echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
        echo ""
        echo -e "  ${WHITE}1)${NC} Laravel Log'unun son 50 satırını görüntüle"
        echo -e "  ${WHITE}2)${NC} Laravel Log'unu canlı izle (tail -f)"
        echo -e "  ${WHITE}3)${NC} APP_DEBUG Değiştir ($([[ "$current_debug" == "true" ]] && echo "Kapat -> false" || echo "Aç -> true"))"
        echo -e "  ${WHITE}4)${NC} Vite / Asset Manifest kontrolü ve derleme (npm build)"
        echo -e "  ${WHITE}5)${NC} Veritabanı bağlantısı ve migration testi"
        echo -e "  ${WHITE}6)${NC} Nginx Error Log (Son 30 satır)"
        echo -e "  ${WHITE}7)${NC} Queue Worker Log (Son 30 satır)"
        echo -e "  ${WHITE}8)${NC} Laravel Log dosyasını temizle / sıfırla"
        echo -e "  ${WHITE}0)${NC} ← Geri Dön"
        echo ""

        local choice
        choice=$(read_menu_choice)

        [[ -z "$choice" ]] && continue

        if [[ "$choice" == "0" || "$choice" == "q" || "$choice" == "Q" ]]; then
            break
        fi

        echo ""

        case "$choice" in
            1)
                local log_file
                log_file=$(get_laravel_log)
                if [[ -f "$log_file" ]]; then
                    print_subheader "Laravel Log (Son 50 Satır)"
                    tail -n 50 "$log_file" | while read -r line; do echo "  $line"; done
                else
                    print_warning "Log dosyası bulunamadı: ${log_file}"
                fi
                press_enter_to_continue
                ;;
            2)
                local log_file
                log_file=$(get_laravel_log)
                if [[ -f "$log_file" ]]; then
                    print_info "Canlı log izleme başlatıldı. Çıkmak için Ctrl+C tuşlarına basın."
                    echo ""
                    tail -f "$log_file"
                else
                    print_warning "Log dosyası bulunamadı: ${log_file}"
                    press_enter_to_continue
                fi
                ;;
            3)
                toggle_app_debug
                press_enter_to_continue
                ;;
            4)
                check_vite_assets
                press_enter_to_continue
                ;;
            5)
                test_database_connection
                press_enter_to_continue
                ;;
            6)
                local nginx_log="/var/log/nginx/error.log"
                if [[ -f "$nginx_log" ]]; then
                    print_subheader "Nginx Error Log (Son 30 Satır)"
                    tail -n 30 "$nginx_log" | while read -r line; do echo "  $line"; done
                else
                    print_warning "Nginx error log bulunamadı."
                fi
                press_enter_to_continue
                ;;
            7)
                local worker_log="${APP_DIR}/storage/logs/worker.log"
                if [[ -f "$worker_log" ]]; then
                    print_subheader "Worker Log (Son 30 Satır)"
                    tail -n 30 "$worker_log" | while read -r line; do echo "  $line"; done
                else
                    print_warning "Worker log bulunamadı: ${worker_log}"
                fi
                press_enter_to_continue
                ;;
            8)
                local log_file
                log_file=$(get_laravel_log)
                if [[ -f "$log_file" ]]; then
                    if confirm_action "Laravel log dosyası sıfırlansın mı?" "e"; then
                        > "$log_file"
                        print_success "Laravel log dosyası temizlendi."
                    fi
                fi
                press_enter_to_continue
                ;;
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                ;;
        esac
    done
}

main "$@"
