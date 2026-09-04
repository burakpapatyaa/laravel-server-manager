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

    print_header "💾 Disk Alanı Temizleme"
    print_banner

    # Mevcut disk kullanımı
    print_subheader "Mevcut Disk Kullanımı"
    df -h / 2>/dev/null | awk 'NR==1 || NR==2'
    echo ""

    local disk_before
    disk_before=$(df / 2>/dev/null | awk 'NR==2 {print $4}')

    echo -e "  ${BOLD}${CYAN}Ne temizlemek istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} 🧹 Tümünü temizle (önerilen)"
    echo -e "  ${WHITE}2)${NC} 📝 Laravel log dosyalarını temizle"
    echo -e "  ${WHITE}3)${NC} 📦 APT cache temizle"
    echo -e "  ${WHITE}4)${NC} 🗑️  Eski kernel'ları temizle"
    echo -e "  ${WHITE}5)${NC} 📓 Journal log temizle"
    echo -e "  ${WHITE}6)${NC} 🔧 /tmp dizinini temizle"
    echo -e "  ${WHITE}7)${NC} 📊 Büyük dosyaları bul (top 20)"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    case "$choice" in
        1)
            print_subheader "Kapsamlı Temizlik"

            # Laravel logları
            if [[ -d "${APP_DIR}/storage/logs" ]]; then
                local log_size
                log_size=$(du -sh "${APP_DIR}/storage/logs" 2>/dev/null | awk '{print $1}')
                print_info "Laravel log boyutu: ${log_size}"

                # Eski logları sil (7 günden eski)
                find "${APP_DIR}/storage/logs" -name "*.log" -mtime +7 -delete 2>/dev/null
                # Ana log dosyasını boşalt (silme)
                if [[ -f "${APP_DIR}/storage/logs/laravel.log" ]]; then
                    > "${APP_DIR}/storage/logs/laravel.log"
                fi
                print_success "Laravel logları temizlendi."
            fi

            # APT cache
            try_run "APT cache temizleniyor" "apt-get autoremove -y && apt-get autoclean -y"

            # Journal logları
            try_run "Journal logları temizleniyor" "journalctl --vacuum-size=100M"

            # /tmp temizliği
            find /tmp -type f -atime +7 -delete 2>/dev/null || true
            print_success "/tmp temizlendi (7 günden eski dosyalar)."
            ;;
        2)
            if [[ -d "${APP_DIR}/storage/logs" ]]; then
                local log_size
                log_size=$(du -sh "${APP_DIR}/storage/logs" 2>/dev/null | awk '{print $1}')
                print_info "Mevcut log boyutu: ${log_size}"

                echo -e "  ${WHITE}a)${NC} Tüm logları temizle"
                echo -e "  ${WHITE}b)${NC} Sadece eski logları temizle (7+ gün)"
                echo -ne "  ${CYAN}Seçiminiz${NC}: "
                read -r log_choice

                if [[ "$log_choice" == "a" ]]; then
                    find "${APP_DIR}/storage/logs" -name "*.log" -delete 2>/dev/null
                    touch "${APP_DIR}/storage/logs/laravel.log"
                    chown www-data:www-data "${APP_DIR}/storage/logs/laravel.log"
                    print_success "Tüm log dosyaları temizlendi."
                else
                    find "${APP_DIR}/storage/logs" -name "*.log" -mtime +7 -delete 2>/dev/null
                    print_success "7 günden eski loglar temizlendi."
                fi
            else
                print_warning "Log dizini bulunamadı."
            fi
            ;;
        3)
            try_run "APT autoremove" "apt-get autoremove -y"
            try_run "APT autoclean" "apt-get autoclean -y"
            try_run "APT clean" "apt-get clean"
            ;;
        4)
            print_step "Eski kernel'lar temizleniyor..."
            apt-get autoremove --purge -y 2>/dev/null
            print_success "Eski kernel'lar temizlendi."
            ;;
        5)
            print_info "Mevcut journal boyutu:"
            journalctl --disk-usage 2>/dev/null
            echo ""
            try_run "Journal logları temizleniyor (100MB'a düşür)" "journalctl --vacuum-size=100M"
            ;;
        6)
            local tmp_size
            tmp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}')
            print_info "/tmp boyutu: ${tmp_size}"

            if confirm_action "7 günden eski geçici dosyalar silinecek. Devam?"; then
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
        0)
            return
            ;;
    esac

    # Temizlik sonrası disk kullanımı
    echo ""
    print_subheader "Temizlik Sonrası Disk Kullanımı"
    df -h / 2>/dev/null | awk 'NR==1 || NR==2'

    local disk_after
    disk_after=$(df / 2>/dev/null | awk 'NR==2 {print $4}')
    local freed=$(( (disk_after - disk_before) ))
    if (( freed > 0 )); then
        print_success "Kazanılan alan: $(human_readable_size $((freed * 1024)) )"
    fi

    log_action "Disk temizliği yapıldı (Seçim: ${choice}). Proje: ${APP_NAME}" "INFO"

    print_completion "Disk Temizleme" "$start_time"
}

main "$@"
