#!/bin/bash
# ============================================================================
# Laravel Server Manager — Queue Worker Yönetimi (fix-queue.sh)
# ============================================================================
# Kullanım: bash scripts/fix-queue.sh
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
        print_header "Queue Worker Yönetimi"
        print_banner

        # Supervisor durumu
        print_subheader "Supervisor Durumu"
        if command -v supervisorctl &> /dev/null; then
            local sup_status
            sup_status=$(check_service_status "supervisor")
            printf "  %-25s %b\n" "Supervisor:" "$sup_status"
            echo ""

            # Worker durumları
            print_step "Worker durumları:"
            supervisorctl status "${APP_NAME}-worker:*" 2>/dev/null || print_info "Worker yapılandırması bulunamadı."
        else
            print_warning "Supervisor kurulu değil!"
        fi

        echo ""
        echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
        echo ""
        echo -e "  ${WHITE}1)${NC} Worker'ları yeniden başlat"
        echo -e "  ${WHITE}2)${NC} Worker'ları durdur"
        echo -e "  ${WHITE}3)${NC} Worker'ları başlat"
        echo -e "  ${WHITE}4)${NC} Queue durumunu göster"
        echo -e "  ${WHITE}5)${NC} Queue'yu temizle (purge)"
        echo -e "  ${WHITE}6)${NC} Worker sayısını değiştir"
        echo -e "  ${WHITE}7)${NC} Supervisor konfigürasyonunu yenile"
        echo -e "  ${WHITE}8)${NC} Queue restart sinyali gönder"
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
                try_run "Queue restart sinyali gönderiliyor" "php ${APP_DIR}/artisan queue:restart"
                if command -v supervisorctl &> /dev/null; then
                    try_run "Worker'lar yeniden başlatılıyor" "supervisorctl restart ${APP_NAME}-worker:*"
                fi
                ;;
            2)
                if command -v supervisorctl &> /dev/null; then
                    try_run "Worker'lar durduruluyor" "supervisorctl stop ${APP_NAME}-worker:*"
                else
                    print_error "Supervisor kurulu değil!"
                fi
                ;;
            3)
                if command -v supervisorctl &> /dev/null; then
                    try_run "Worker'lar başlatılıyor" "supervisorctl start ${APP_NAME}-worker:*"
                else
                    print_error "Supervisor kurulu değil!"
                fi
                ;;
            4)
                print_subheader "Queue Durumu"
                cd "$APP_DIR"
                php artisan queue:monitor "${QUEUE_CONNECTION}:default" 2>/dev/null || print_info "Queue monitor kullanılamıyor."

                # Bekleyen job sayısı
                local pending_count
                pending_count=$(php artisan tinker --execute="echo DB::table('jobs')->count();" 2>/dev/null || echo "Bilinmiyor")
                print_table_row "Bekleyen Job:" "$pending_count" "$YELLOW"

                local failed_count
                failed_count=$(php artisan tinker --execute="echo DB::table('failed_jobs')->count();" 2>/dev/null || echo "Bilinmiyor")
                print_table_row "Başarısız Job:" "$failed_count" "$RED"
                cd - > /dev/null
                ;;
            5)
                if confirm_action "Tüm bekleyen job'lar silinecek! Emin misiniz?" "h"; then
                    cd "$APP_DIR"
                    try_run "Queue temizleniyor" "php artisan queue:clear ${QUEUE_CONNECTION}"
                    cd - > /dev/null
                fi
                ;;
            6)
                read_required "Yeni worker sayısı" new_workers "$SUPERVISOR_WORKERS"
                update_config_value "SUPERVISOR_WORKERS" "$new_workers"

                # Supervisor config güncelle
                local supervisor_conf="/etc/supervisor/conf.d/${APP_NAME}-worker.conf"
                if [[ -f "$supervisor_conf" ]]; then
                    sed -i "s/^numprocs=.*/numprocs=${new_workers}/" "$supervisor_conf"
                    try_run "Supervisor yeniden yükleniyor" "supervisorctl reread && supervisorctl update"
                    print_success "Worker sayısı ${new_workers} olarak güncellendi."
                else
                    print_warning "Supervisor config bulunamadı: ${supervisor_conf}"
                fi
                ;;
            7)
                if command -v supervisorctl &> /dev/null; then
                    try_run "Supervisor konfigürasyonu yeniden okunuyor" "supervisorctl reread"
                    try_run "Supervisor güncelleniyor" "supervisorctl update"
                else
                    print_error "Supervisor kurulu değil!"
                fi
                ;;
            8)
                try_run "Queue restart sinyali gönderiliyor" "php ${APP_DIR}/artisan queue:restart"
                ;;
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                continue
                ;;
        esac

        log_action "Queue yönetimi işlemi yapıldı (Seçim: ${choice}). Proje: ${APP_NAME}" "INFO"
        press_enter_to_continue
    done

    print_completion "Queue Yönetimi" "$start_time"
}

main "$@"
