#!/bin/bash
# ============================================================================
# Laravel Server Manager — Veritabanı Yedeği (backup-db.sh)
# ============================================================================
# Kullanım: bash scripts/backup-db.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "📦 Veritabanı Yedeği"
    print_banner

    # Yedekleme dizini oluştur
    mkdir -p "$BACKUP_DIR"

    echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} Yeni yedek al"
    echo -e "  ${WHITE}2)${NC} Mevcut yedekleri listele"
    echo -e "  ${WHITE}3)${NC} Eski yedekleri temizle (${BACKUP_RETENTION_DAYS}+ gün)"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    case "$choice" in
        1)
            local backup_file="${BACKUP_DIR}/${DB_NAME}_$(datestamp).sql.gz"

            print_step "Veritabanı yedekleniyor: ${DB_NAME}"
            print_info "Hedef: ${backup_file}"
            echo ""

            # mysqldump ile yedek al ve gzip ile sıkıştır
            if mysqldump -u"${DB_USER}" -p"${DB_PASS}" --single-transaction --routines --triggers --events "${DB_NAME}" 2>/dev/null | gzip > "$backup_file"; then
                local backup_size
                backup_size=$(du -sh "$backup_file" 2>/dev/null | awk '{print $1}')
                print_success "Yedekleme tamamlandı!"
                print_table_row "Dosya:" "$backup_file" "$WHITE"
                print_table_row "Boyut:" "$backup_size" "$GREEN"

                log_action "Veritabanı yedeklendi: ${backup_file} (${backup_size})" "SUCCESS"
            else
                rm -f "$backup_file" 2>/dev/null
                print_error "Yedekleme başarısız oldu!"
                log_action "Veritabanı yedekleme başarısız: ${DB_NAME}" "ERROR"
            fi
            ;;
        2)
            print_subheader "Mevcut Yedekler"

            if [[ -d "$BACKUP_DIR" ]]; then
                local count=0
                while IFS= read -r file; do
                    local size
                    size=$(du -sh "$file" 2>/dev/null | awk '{print $1}')
                    local date_str
                    date_str=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)
                    printf "  ${WHITE}%-45s${NC}  ${GRAY}%s${NC}  ${CYAN}%s${NC}\n" "$(basename "$file")" "$size" "$date_str"
                    count=$((count + 1))
                done < <(find "$BACKUP_DIR" -name "*.sql.gz" -type f | sort -r)

                if [[ $count -eq 0 ]]; then
                    print_info "Henüz yedek alınmamış."
                else
                    echo ""
                    print_info "Toplam ${count} yedek bulundu."

                    # Toplam boyut
                    local total_size
                    total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | awk '{print $1}')
                    print_table_row "Toplam Boyut:" "$total_size" "$YELLOW"
                fi
            fi
            ;;
        3)
            local old_count
            old_count=$(find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"${BACKUP_RETENTION_DAYS}" 2>/dev/null | wc -l)

            if [[ "$old_count" -gt 0 ]]; then
                print_info "${old_count} adet eski yedek bulundu (${BACKUP_RETENTION_DAYS}+ gün)."

                if confirm_action "Bu yedekler silinecek. Devam?"; then
                    find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"${BACKUP_RETENTION_DAYS}" -delete 2>/dev/null
                    print_success "${old_count} eski yedek silindi."
                    log_action "${old_count} eski yedek temizlendi." "INFO"
                fi
            else
                print_info "Temizlenecek eski yedek bulunamadı."
            fi
            ;;
        0)
            return
            ;;
    esac

    print_completion "Veritabanı Yedeği" "$start_time"
}

main "$@"
