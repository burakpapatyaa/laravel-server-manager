#!/bin/bash
# ============================================================================
# Laravel Server Manager — Ayar Yönetim Ekranı (settings.sh)
# ============================================================================
# Kullanım: bash scripts/settings.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Error trap
enable_error_trap

# ============================================================================
# FONKSİYONLAR
# ============================================================================

# Mevcut ayarları göster
show_current_settings() {
    load_config

    print_header "⚙️ Mevcut Ayarlar"

    print_subheader "Proje Bilgileri"
    print_table_row "Proje Adı:" "$APP_NAME" "$GREEN"
    print_table_row "Proje Dizini:" "$APP_DIR" "$WHITE"
    print_table_row "Domain:" "${DOMAIN:-Yapılandırılmadı}" "$WHITE"
    print_table_row "Sunucu IP:" "$SERVER_IP" "$WHITE"

    print_subheader "GitHub Bilgileri"
    print_table_row "Kullanıcı:" "$GITHUB_USER" "$WHITE"
    print_table_row "Repo:" "$GITHUB_REPO" "$WHITE"
    print_table_row "Branch:" "$GITHUB_BRANCH" "$WHITE"
    print_table_row "Repo Tipi:" "$REPO_VISIBILITY" "$WHITE"
    local masked_token
    if [[ -n "$GITHUB_TOKEN" ]]; then
        masked_token="${GITHUB_TOKEN:0:4}****${GITHUB_TOKEN: -4}"
    else
        masked_token="Yok"
    fi
    print_table_row "Token:" "$masked_token" "$YELLOW"

    print_subheader "Veritabanı Bilgileri"
    print_table_row "DB Adı:" "$DB_NAME" "$WHITE"
    print_table_row "DB Kullanıcı:" "$DB_USER" "$WHITE"
    print_table_row "DB Şifre:" "********" "$RED"

    print_subheader "PHP & Genel"
    print_table_row "PHP Sürümü:" "$PHP_VERSION" "$YELLOW"
    print_table_row "Yedekleme Dizini:" "$BACKUP_DIR" "$WHITE"
    print_table_row "Yedek Saklama:" "${BACKUP_RETENTION_DAYS} gün" "$WHITE"
    print_table_row "Worker Sayısı:" "$SUPERVISOR_WORKERS" "$WHITE"
    print_table_row "Queue Bağlantısı:" "$QUEUE_CONNECTION" "$WHITE"
    print_table_row "Kurulum Tarihi:" "${LSM_INSTALLED_AT:-Bilinmiyor}" "$GRAY"
    print_table_row "Son Deploy:" "${DEPLOY_TIMESTAMP:-Henüz yapılmadı}" "$GRAY"
}

# Ayar menüsü
show_settings_menu() {
    echo ""
    echo -e "  ${BOLD}${CYAN}Hangi ayarı değiştirmek istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE} 1)${NC} Proje Adı"
    echo -e "  ${WHITE} 2)${NC} Proje Dizini"
    echo -e "  ${WHITE} 3)${NC} Domain"
    echo -e "  ${WHITE} 4)${NC} Sunucu IP"
    echo -e "  ${WHITE} 5)${NC} GitHub Kullanıcı"
    echo -e "  ${WHITE} 6)${NC} GitHub Repo"
    echo -e "  ${WHITE} 7)${NC} GitHub Branch"
    echo -e "  ${WHITE} 8)${NC} Repo Tipi (Public/Private)"
    echo -e "  ${WHITE} 9)${NC} GitHub Token (PAT)"
    echo -e "  ${WHITE}10)${NC} Veritabanı Adı"
    echo -e "  ${WHITE}11)${NC} Veritabanı Kullanıcı"
    echo -e "  ${WHITE}12)${NC} Veritabanı Şifresi"
    echo -e "  ${WHITE}13)${NC} PHP Sürümü"
    echo -e "  ${WHITE}14)${NC} Yedekleme Dizini"
    echo -e "  ${WHITE}15)${NC} Yedek Saklama Süresi"
    echo -e "  ${WHITE}16)${NC} Worker Sayısı"
    echo -e "  ${WHITE}17)${NC} Queue Bağlantı Tipi"
    echo ""
    echo -e "  ${MAGENTA}── Sunucu Limitleri ──${NC}"
    echo -e "  ${WHITE}18)${NC} Upload Boyutu (upload_max_filesize / client_max_body_size)"
    echo -e "  ${WHITE}19)${NC} PHP Memory Limiti (memory_limit)"
    echo -e "  ${WHITE}20)${NC} Timeout (max_execution_time / fastcgi_read_timeout)"
    echo ""
    echo -e "  ${MAGENTA}── İçe/Dışa Aktarma ──${NC}"
    echo -e "  ${WHITE}23)${NC} 📤 Config Dışa Aktar"
    echo -e "  ${WHITE}24)${NC} 📥 Config İçe Aktar"
    echo -e "  ${WHITE}25)${NC} 🔄 Tüm Ayarları Sıfırla"
    echo ""
    echo -e "  ${WHITE} 0)${NC} ← Geri Dön"
}

# Ayar değiştirme işlemi
change_setting() {
    local choice="$1"

    case "$choice" in
        1)
            read_required "Yeni proje adı" new_value "$APP_NAME"
            update_config_value "APP_NAME" "$new_value"
            ;;
        2)
            read_required "Yeni proje dizini" new_value "$APP_DIR"
            if validate_path "$new_value"; then
                update_config_value "APP_DIR" "$new_value"
            else
                print_error "Geçersiz dizin yolu! Mutlak yol kullanın (/ ile başlamalı)."
                return 1
            fi
            ;;
        3)
            read_optional "Yeni domain" new_value "$DOMAIN"
            update_config_value "DOMAIN" "$new_value"
            ;;
        4)
            read_required "Yeni sunucu IP" new_value "$SERVER_IP"
            if validate_ip "$new_value"; then
                update_config_value "SERVER_IP" "$new_value"
            else
                print_error "Geçersiz IP adresi!"
                return 1
            fi
            ;;
        5)
            read_required "Yeni GitHub kullanıcı adı" new_value "$GITHUB_USER"
            update_config_value "GITHUB_USER" "$new_value"
            ;;
        6)
            read_required "Yeni GitHub repo adı" new_value "$GITHUB_REPO"
            update_config_value "GITHUB_REPO" "$new_value"
            ;;
        7)
            read_required "Yeni branch adı" new_value "$GITHUB_BRANCH"
            update_config_value "GITHUB_BRANCH" "$new_value"
            ;;
        8)
            echo -e "  ${CYAN}Repo tipi:${NC}"
            echo -e "    ${WHITE}1)${NC} Public"
            echo -e "    ${WHITE}2)${NC} Private"
            echo -ne "  ${CYAN}Seçiminiz${NC}: "
            read -r rt_choice
            if [[ "$rt_choice" == "2" ]]; then
                update_config_value "REPO_VISIBILITY" "private"
                print_info "Private repo için token gerektiğini unutmayın."
            else
                update_config_value "REPO_VISIBILITY" "public"
            fi
            ;;
        9)
            read_secret "Yeni GitHub Token (PAT)" new_value
            update_config_value "GITHUB_TOKEN" "$new_value"
            ;;
        10)
            read_required "Yeni veritabanı adı" new_value "$DB_NAME"
            update_config_value "DB_NAME" "$new_value"
            print_warning "Veritabanı adını değiştirmek mevcut bağlantıyı etkileyebilir!"
            ;;
        11)
            read_required "Yeni veritabanı kullanıcı adı" new_value "$DB_USER"
            update_config_value "DB_USER" "$new_value"
            ;;
        12)
            read_secret "Yeni veritabanı şifresi" new_value
            update_config_value "DB_PASS" "$new_value"
            print_info ".env dosyasını da güncellemeyi unutmayın!"
            ;;
        13)
            bash "${SCRIPT_DIR}/switch-php.sh"
            load_config
            return 255
            ;;
        14)
            read_required "Yeni yedekleme dizini" new_value "$BACKUP_DIR"
            update_config_value "BACKUP_DIR" "$new_value"
            ;;
        15)
            read_required "Yedek saklama süresi (gün)" new_value "$BACKUP_RETENTION_DAYS"
            update_config_value "BACKUP_RETENTION_DAYS" "$new_value"
            ;;
        16)
            read_required "Worker sayısı" new_value "$SUPERVISOR_WORKERS"
            update_config_value "SUPERVISOR_WORKERS" "$new_value"
            print_info "Değişikliğin uygulanması için Supervisor yeniden başlatılmalı."
            ;;
        17)
            echo -e "  ${CYAN}Queue bağlantı tipi:${NC}"
            echo -e "    ${WHITE}1)${NC} database"
            echo -e "    ${WHITE}2)${NC} redis"
            echo -e "    ${WHITE}3)${NC} sqs"
            echo -e "    ${WHITE}4)${NC} sync"
            echo -ne "  ${CYAN}Seçiminiz${NC}: "
            read -r qc_choice
            case "$qc_choice" in
                2) update_config_value "QUEUE_CONNECTION" "redis" ;;
                3) update_config_value "QUEUE_CONNECTION" "sqs" ;;
                4) update_config_value "QUEUE_CONNECTION" "sync" ;;
                *) update_config_value "QUEUE_CONNECTION" "database" ;;
            esac
            ;;
        18)
            read_required "Upload boyutu (örn: 50M, 100M, 200M)" new_value "${UPLOAD_MAX_SIZE:-100M}"
            update_config_value "UPLOAD_MAX_SIZE" "$new_value"
            print_info "PHP ini ve Nginx'te uygulamak için: deploy.sh çalıştırın veya sunucuda manuel olarak güncelleyin."
            ;;
        19)
            read_required "PHP memory limiti (örn: 256M, 512M, 1G)" new_value "${PHP_MEMORY_LIMIT:-512M}"
            update_config_value "PHP_MEMORY_LIMIT" "$new_value"
            print_info "PHP ini'de uygulamak için: deploy.sh çalıştırın veya sunucuda manuel olarak güncelleyin."
            ;;
        20)
            read_required "Timeout süresi saniye cinsinden (örn: 120, 300, 600)" new_value "${MAX_EXECUTION_TIME:-300}"
            update_config_value "MAX_EXECUTION_TIME" "$new_value"
            print_info "PHP ini ve Nginx'te uygulamak için: deploy.sh çalıştırın veya sunucuda manuel olarak güncelleyin."
            ;;
        23)
            # Config dışa aktar
            local export_dir="${SCRIPT_DIR}/exports"
            mkdir -p "$export_dir"
            local export_file="${export_dir}/config_export_$(datestamp).sh"

            if confirm_action "Hassas bilgileri (şifre, token) maskelensin mi?" "e"; then
                export_config "$export_file" "true"
            else
                export_config "$export_file" "false"
            fi
            ;;
        24)
            # Config içe aktar
            read_required "İçe aktarılacak dosya yolu" import_file
            if [[ -f "$import_file" ]]; then
                if confirm_action "Mevcut config üzerine yazılacak. Devam edilsin mi?" "h"; then
                    import_config "$import_file"
                    print_info "Config yeniden yükleniyor..."
                    load_config
                else
                    print_info "İçe aktarma iptal edildi."
                fi
            else
                print_error "Dosya bulunamadı: ${import_file}"
            fi
            ;;
        25)
            # Tüm ayarları sıfırla
            if confirm_action "⚠️  TÜM AYARLAR SİLİNECEK! Emin misiniz?" "h"; then
                if confirm_action "Son kez onaylayın — config dosyası silinecek!" "h"; then
                    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(datestamp)"
                    rm -f "$CONFIG_FILE"
                    print_success "Ayarlar sıfırlandı. Yeniden kurulum için: sudo bash ${SCRIPT_DIR}/install.sh"
                    exit 0
                fi
            fi
            print_info "Sıfırlama iptal edildi."
            ;;
        0)
            return 255  # Geri dön sinyali
            ;;
        *)
            print_warning "Geçersiz seçim!"
            ;;
    esac
}

# ============================================================================
# ANA AKIŞ
# ============================================================================

main() {
    while true; do
        clear
        print_banner
        show_current_settings
        show_settings_menu

        local choice
        choice=$(read_menu_choice)

        if [[ "$choice" == "0" || "$choice" == "q" || "$choice" == "Q" ]]; then
            break
        fi

        echo ""
        change_setting "$choice"

        if [[ $? -ne 255 ]]; then
            # Config'i yeniden yükle
            load_config
            press_enter_to_continue
        fi
    done
}

main "$@"
