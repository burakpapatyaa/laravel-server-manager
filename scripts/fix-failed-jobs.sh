#!/bin/bash
# ============================================================================
# Laravel Server Manager — Başarısız Job Yönetimi (fix-failed-jobs.sh)
# ============================================================================
# Kullanım: bash scripts/fix-failed-jobs.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "❌ Başarısız Job Yönetimi"
    print_banner

    if [[ ! -d "$APP_DIR" ]]; then
        print_error "Proje dizini bulunamadı: ${APP_DIR}"
        exit 1
    fi

    cd "$APP_DIR"

    # Başarısız job'ları listele
    print_subheader "Başarısız Job Listesi"
    php artisan queue:failed 2>/dev/null || print_info "Başarısız job bulunamadı veya tablo mevcut değil."

    echo ""
    echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} Tüm başarısız job'ları tekrar dene"
    echo -e "  ${WHITE}2)${NC} Belirli bir job'u tekrar dene (ID ile)"
    echo -e "  ${WHITE}3)${NC} Tüm başarısız job'ları sil"
    echo -e "  ${WHITE}4)${NC} Belirli bir job'u sil (ID ile)"
    echo -e "  ${WHITE}5)${NC} Başarısız job tablosunu oluştur (migrate)"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    case "$choice" in
        1)
            if confirm_action "Tüm başarısız job'lar tekrar denenecek. Devam edilsin mi?"; then
                try_run_verbose "Tüm başarısız job'lar tekrar deneniyor" "php artisan queue:retry all"
            fi
            ;;
        2)
            read_required "Job ID" job_id
            try_run_verbose "Job #${job_id} tekrar deneniyor" "php artisan queue:retry ${job_id}"
            ;;
        3)
            if confirm_action "⚠️  Tüm başarısız job'lar kalıcı olarak silinecek! Emin misiniz?" "h"; then
                try_run "Tüm başarısız job'lar siliniyor" "php artisan queue:flush"
                print_success "Tüm başarısız job'lar silindi."
            fi
            ;;
        4)
            read_required "Silinecek Job ID" job_id
            try_run "Job #${job_id} siliniyor" "php artisan queue:forget ${job_id}"
            ;;
        5)
            try_run_verbose "Failed jobs tablosu oluşturuluyor" "php artisan queue:failed-table && php artisan migrate --force"
            ;;
        0)
            cd - > /dev/null
            return
            ;;
        *)
            print_warning "Geçersiz seçim!"
            ;;
    esac

    log_action "Başarısız job yönetimi (Seçim: ${choice}). Proje: ${APP_NAME}" "INFO"
    cd - > /dev/null

    print_completion "Başarısız Job Yönetimi" "$start_time"
}

main "$@"
