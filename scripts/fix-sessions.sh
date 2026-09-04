#!/bin/bash
# ============================================================================
# Laravel Server Manager — Session Yönetimi (fix-sessions.sh)
# ============================================================================
# Kullanım: bash scripts/fix-sessions.sh
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
        print_header "Session Yönetimi"
        print_banner

        # Session driver bilgisi
        print_subheader "Session Bilgisi"

        local session_driver
        session_driver=$(grep "^SESSION_DRIVER=" "${APP_DIR}/.env" 2>/dev/null | cut -d'=' -f2 || echo "Bilinmiyor")
        local session_lifetime
        session_lifetime=$(grep "^SESSION_LIFETIME=" "${APP_DIR}/.env" 2>/dev/null | cut -d'=' -f2 || echo "120")

        print_table_row "Session Driver:" "$session_driver" "$YELLOW"
        print_table_row "Session Ömrü:" "${session_lifetime} dakika" "$WHITE"

        # Driver'a göre ek bilgi
        case "$session_driver" in
            file)
                local session_dir="${APP_DIR}/storage/framework/sessions"
                if [[ -d "$session_dir" ]]; then
                    local session_count
                    session_count=$(find "$session_dir" -type f | wc -l)
                    local session_size
                    session_size=$(du -sh "$session_dir" 2>/dev/null | awk '{print $1}')
                    print_table_row "Session Sayısı:" "$session_count" "$WHITE"
                    print_table_row "Toplam Boyut:" "$session_size" "$WHITE"
                fi
                ;;
            database)
                cd "$APP_DIR"
                local db_session_count
                db_session_count=$(php artisan tinker --execute="echo DB::table('sessions')->count();" 2>/dev/null || echo "Bilinmiyor")
                print_table_row "DB Session Sayısı:" "$db_session_count" "$WHITE"
                cd - > /dev/null
                ;;
        esac

        echo ""
        echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
        echo ""
        echo -e "  ${WHITE}1)${NC} Eski session'ları temizle"
        echo -e "  ${WHITE}2)${NC} Tüm session'ları temizle"
        echo -e "  ${WHITE}3)${NC} Session konfigürasyonunu göster"
        echo -e "  ${WHITE}4)${NC} Session driver'ını değiştir"
        echo -e "  ${WHITE}5)${NC} Session tablosu oluştur (database driver için)"
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
                case "$session_driver" in
                    file)
                        local old_count
                        old_count=$(find "${APP_DIR}/storage/framework/sessions" -type f -mmin +$((session_lifetime)) 2>/dev/null | wc -l)
                        print_info "${old_count} eski session dosyası bulundu."
                        find "${APP_DIR}/storage/framework/sessions" -type f -mmin +$((session_lifetime)) -delete 2>/dev/null
                        print_success "Eski session dosyaları temizlendi."
                        ;;
                    database)
                        cd "$APP_DIR"
                        php artisan tinker --execute="DB::table('sessions')->where('last_activity', '<', now()->subMinutes(${session_lifetime})->getTimestamp())->delete();" 2>/dev/null
                        print_success "Eski session kayıtları temizlendi."
                        cd - > /dev/null
                        ;;
                    *)
                        print_info "Bu driver için otomatik temizleme desteklenmiyor: ${session_driver}"
                        ;;
                esac
                ;;
            2)
                if confirm_action "⚠️  Tüm session'lar silinecek! Aktif kullanıcılar çıkış yapar. Emin misiniz?" "h"; then
                    case "$session_driver" in
                        file)
                            find "${APP_DIR}/storage/framework/sessions" -type f -delete 2>/dev/null
                            print_success "Tüm session dosyaları silindi."
                            ;;
                        database)
                            cd "$APP_DIR"
                            php artisan tinker --execute="DB::table('sessions')->truncate();" 2>/dev/null
                            print_success "Tüm session kayıtları silindi."
                            cd - > /dev/null
                            ;;
                        redis)
                            cd "$APP_DIR"
                            try_run "Redis session'ları temizleniyor" "php artisan cache:clear"
                            cd - > /dev/null
                            ;;
                    esac
                fi
                ;;
            3)
                print_subheader "Session Konfigürasyonu (.env)"
                grep -i "session" "${APP_DIR}/.env" 2>/dev/null | while read -r line; do
                    echo -e "  ${WHITE}${line}${NC}"
                done
                ;;
            4)
                echo -e "  ${CYAN}Session driver seçin:${NC}"
                echo -e "    ${WHITE}1)${NC} file"
                echo -e "    ${WHITE}2)${NC} database"
                echo -e "    ${WHITE}3)${NC} redis"
                echo -e "    ${WHITE}4)${NC} cookie"
                echo -ne "  ${CYAN}Seçiminiz${NC}: "
                read -r drv_choice

                local new_driver
                case "$drv_choice" in
                    1) new_driver="file" ;;
                    2) new_driver="database" ;;
                    3) new_driver="redis" ;;
                    4) new_driver="cookie" ;;
                    *) new_driver="file" ;;
                esac

                sed -i "s/^SESSION_DRIVER=.*/SESSION_DRIVER=${new_driver}/" "${APP_DIR}/.env" 2>/dev/null
                print_success "Session driver '${new_driver}' olarak güncellendi."
                print_info "Cache'i temizlemeyi unutmayın: php artisan config:cache"
                ;;
            5)
                cd "$APP_DIR"
                try_run_verbose "Session tablosu oluşturuluyor" "php artisan session:table && php artisan migrate --force"
                cd - > /dev/null
                ;;
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                continue
                ;;
        esac

        log_action "Session yönetimi (Seçim: ${choice}). Proje: ${APP_NAME}" "INFO"
        press_enter_to_continue
    done

    print_completion "Session Yönetimi" "$start_time"
}

main "$@"
