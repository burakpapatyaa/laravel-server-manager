#!/bin/bash
# ============================================================================
# Laravel Server Manager — Yedekten Geri Yükle (restore-db.sh)
# ============================================================================
# Kullanım: bash scripts/restore-db.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "Yedekleme dizini bulunamadı: ${BACKUP_DIR}"
        exit 1
    fi

    while true; do
        clear
        print_header "Yedekten Geri Yükleme"
        print_banner

        # Mevcut yedekleri listele
        print_subheader "Mevcut Yedekler"

        local backups=()
        local idx=1

        while IFS= read -r file; do
            backups+=("$file")
            local size
            size=$(du -sh "$file" 2>/dev/null | awk '{print $1}')
            local date_str
            date_str=$(stat -c "%y" "$file" 2>/dev/null | cut -d'.' -f1)
            printf "  ${WHITE}%2d)${NC} %-40s  ${GRAY}%s${NC}  ${CYAN}%s${NC}\n" "$idx" "$(basename "$file")" "$size" "$date_str"
            idx=$((idx + 1))
        done < <(find "$BACKUP_DIR" -name "*.sql.gz" -type f | sort -r)

        if [[ ${#backups[@]} -eq 0 ]]; then
            print_info "Yedek bulunamadı. Önce yedek alın: bash scripts/backup-db.sh"
            press_enter_to_continue
            break
        fi

        echo ""
        echo -e "  ${WHITE} 0)${NC} ← Geri Dön"

        # Yedek seçimi
        local choice
        choice=$(read_menu_choice "Geri yüklenecek yedek numarası")

        [[ -z "$choice" ]] && continue

        if [[ "$choice" == "0" || "$choice" == "q" || "$choice" == "Q" ]]; then
            break
        fi

        local selected_idx=$((choice - 1))
        if [[ $selected_idx -lt 0 || $selected_idx -ge ${#backups[@]} ]]; then
            print_error "Geçersiz seçim!"
            sleep 1
            continue
        fi

        local selected_file="${backups[$selected_idx]}"
        print_info "Seçilen yedek: $(basename "$selected_file")"

        echo ""
        print_warning "⚠️  Geri yükleme mevcut veritabanını TAMAMEN SİLECEK!"
        print_warning "Veritabanı: ${DB_NAME}"

        if ! confirm_action "Devam etmek istiyor musunuz?" "h"; then
            print_info "Geri yükleme iptal edildi."
            press_enter_to_continue
            continue
        fi

        # Mevcut DB'nin otomatik yedeğini al
        echo ""
        print_step "Güvenlik: Mevcut veritabanı yedekleniyor..."
        local safety_backup="${BACKUP_DIR}/${DB_NAME}_pre_restore_$(datestamp).sql.gz"

        if mysqldump -u"${DB_USER}" -p"${DB_PASS}" --single-transaction "${DB_NAME}" 2>/dev/null | gzip > "$safety_backup"; then
            print_success "Güvenlik yedeği alındı: $(basename "$safety_backup")"
        else
            print_warning "Güvenlik yedeği alınamadı!"
            if ! confirm_action "Yedek olmadan devam etmek ister misiniz?" "h"; then
                press_enter_to_continue
                continue
            fi
        fi

        # Geri yükleme
        echo ""
        print_step "Veritabanı geri yükleniyor..."

        if gunzip -c "$selected_file" | mysql -u"${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" 2>/dev/null; then
            print_success "Geri yükleme başarıyla tamamlandı!"
            print_table_row "Kaynak:" "$(basename "$selected_file")" "$WHITE"
            print_table_row "Hedef DB:" "$DB_NAME" "$GREEN"

            log_action "Veritabanı geri yüklendi: $(basename "$selected_file") → ${DB_NAME}" "SUCCESS"
        else
            print_error "Geri yükleme başarısız oldu!"
            print_info "Güvenlik yedeğinden geri yüklemek için:"
            echo -e "    ${YELLOW}gunzip -c ${safety_backup} | mysql -u${DB_USER} -p ${DB_NAME}${NC}"

            log_action "Veritabanı geri yükleme başarısız: $(basename "$selected_file")" "ERROR"
        fi

        press_enter_to_continue
    done

    print_completion "Geri Yükleme" "$start_time"
}

main "$@"
