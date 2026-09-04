#!/bin/bash
# ============================================================================
# Laravel Server Manager — Disk Alanı Temizle (fix-disk.sh)
# ============================================================================
# Kullanım: sudo bash scripts/fix-disk.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    while true; do
        clear
        print_header "Disk Alanı Temizleme"
        print_banner

        # Mevcut disk kullanımı
        print_subheader "Mevcut Disk Kullanımı"
        df -h / 2>/dev/null | awk 'NR==1 || NR==2'
        echo ""

        local disk_before
        disk_before=$(df / 2>/dev/null | awk 'NR==2 {print $4}')

        echo -e "  ${BOLD}${CYAN}Ne temizlemek istiyorsunuz?${NC}"
        echo ""
        echo -e "  ${WHITE}1)${NC} Tümünü temizle (önerilen)"
        echo -e "  ${WHITE}2)${NC} Laravel log dosyalarını temizle"
        echo -e "  ${WHITE}3)${NC} APT cache temizle"
        echo -e "  ${WHITE}4)${NC} Eski kernel'ları temizle"
        echo -e "  ${WHITE}5)${NC} Journal log temizle"
        echo -e "  ${WHITE}6)${NC} /tmp dizinini temizle"
        echo -e "  ${WHITE}7)${NC} Büyük dosyaları bul (top 20)"
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
                print_subheader "Kapsamlı Temizlik"

                # Laravel logları
                if [[ -d "${APP_DIR}/storage/logs" ]]; then
                    local log_size
                    log_size=$(du -sh "${APP_DIR}/storage/logs" 2>/dev/null | awk '{print $1}')
                    print_info "Laravel log boyutu: ${log_size}"

                    find "${APP_DIR}/storage/logs" -name "*.log" -mtime +7 -delete 2>/dev/null
                    if [[ -f "${APP_DIR}/storage/logs/laravel.log" ]]; then
                        > "${APP_DIR}/storage/logs/laravel.log"
                    fi
                    print_success "Laravel logları temizlendi."
                fi

                # APT cache
                try_run "APT cache temizleniyor" "apt-get autoremove -y && apt-get autoclean -y"

                # Journal log
                try_run "Journal logları temizleniyor" "journalctl --vacuum-time=7d"

                # /tmp
                print_step "/tmp temizleniyor..."
                find /tmp -type f -atime +7 -delete 2>/dev/null || true
                print_success "/tmp temizlendi."
                ;;
            2)
                print_subheader "Laravel Log Temizliği"
                if [[ -d "${APP_DIR}/storage/logs" ]]; then
                    find "${APP_DIR}/storage/logs" -name "*.log" -mtime +3 -delete 2>/dev/null
                    if [[ -f "${APP_DIR}/storage/logs/laravel.log" ]]; then
                        local before_size
                        before_size=$(du -sh "${APP_DIR}/storage/logs/laravel.log" 2>/dev/null | awk '{print $1}')
                        > "${APP_DIR}/storage/logs/laravel.log"
                        print_success "laravel.log temizlendi (${before_size} -> 0B)."
                    fi
                    print_success "Eski loglar silindi."
                else
                    print_warning "Log dizini bulunamadı: ${APP_DIR}/storage/logs"
                fi
                ;;
            3)
                print_subheader "APT Cache Temizliği"
                try_run "APT autoremove" "apt-get autoremove -y"
                try_run "APT autoclean" "apt-get autoclean -y"
                try_run "APT clean" "apt-get clean"
                ;;
            4)
                print_subheader "Eski Kernel'lar Temizleniyor"
                try_run "Eski kernel'lar kaldırılıyor" "apt-get --purge autoremove -y"
                ;;
            5)
                print_subheader "Journal Log Temizliği"
                print_info "Mevcut journal boyutu:"
                journalctl --disk-usage 2>&1 | while read -r line; do echo "  $line"; done
                echo ""
                try_run "7 günden eski loglar siliniyor" "journalctl --vacuum-time=7d"
                try_run "Log boyutu 100MB ile sınırlandırılıyor" "journalctl --vacuum-size=100M"
                ;;
            6)
                print_subheader "/tmp Dizini Temizliği"
                local tmp_count
                tmp_count=$(find /tmp -type f 2>/dev/null | wc -l)
                print_info "/tmp içindeki dosya sayısı: ${tmp_count}"

                if confirm_action "/tmp içindeki 7 günden eski dosyalar silinsin mi?"; then
                    find /tmp -type f -atime +7 -delete 2>/dev/null || true
                    print_success "/tmp temizlendi."
                fi
                ;;
            7)
                print_subheader "En Büyük 20 Dosya"
                find / -xdev -type f -size +50M 2>/dev/null | head -20 | while read -r f; do
                    local size
                    size=$(du -sh "$f" 2>/dev/null | awk '{print $1}')
                    printf "  %-8s %s\n" "$size" "$f"
                done
                ;;
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                continue
                ;;
        esac

        # Temizlik sonrası disk kullanımı
        if [[ "$choice" != "7" ]]; then
            echo ""
            print_subheader "Temizlik Sonrası Disk Kullanımı"
            df -h / 2>/dev/null | awk 'NR==1 || NR==2'

            local disk_after
            disk_after=$(df / 2>/dev/null | awk 'NR==2 {print $4}')
            local freed=$(( (disk_after - disk_before) ))
            if (( freed > 0 )); then
                print_success "Kazanılan alan: $(human_readable_size $((freed * 1024)) )"
            fi
        fi

        log_action "Disk temizliği yapıldı (Seçim: ${choice}). Proje: ${APP_NAME}" "INFO"
        press_enter_to_continue
    done

    print_completion "Disk Temizleme" "$start_time"
}

main "$@"
