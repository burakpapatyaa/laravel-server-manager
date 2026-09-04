#!/bin/bash
# ============================================================================
# Laravel Server Manager — SSL Kurulumu (setup-ssl.sh)
# ============================================================================
# Kullanım: sudo bash scripts/setup-ssl.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🔒 SSL Kurulumu (Let's Encrypt)"
    print_banner

    require_root

    # Domain kontrolü
    if [[ -z "$DOMAIN" ]]; then
        print_error "Domain adı yapılandırılmamış!"
        print_info "Önce domain belirleyin: bash scripts/settings.sh"
        read_required "Domain adı girin" DOMAIN
        update_config_value "DOMAIN" "$DOMAIN"
    fi

    print_info "Domain: ${DOMAIN}"

    # Certbot kontrolü
    if ! command -v certbot &> /dev/null; then
        print_warning "Certbot kurulu değil. Kuruluyor..."
        try_run "Certbot kuruluyor" "apt-get install -y certbot python3-certbot-nginx"
    fi

    echo ""
    echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} 🔒 Yeni SSL sertifikası al"
    echo -e "  ${WHITE}2)${NC} 🔄 Mevcut sertifikayı yenile"
    echo -e "  ${WHITE}3)${NC} 📋 Sertifika durumunu göster"
    echo -e "  ${WHITE}4)${NC} ⏰ Otomatik yenileme cron kontrolü"
    echo -e "  ${WHITE}5)${NC} 🧪 Yenileme testi (dry-run)"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    case "$choice" in
        1)
            print_subheader "SSL Sertifikası Alınıyor"

            # E-posta adresi
            read_required "E-posta adresi (Let's Encrypt bildirimleri için)" ssl_email

            print_info "Domain: ${DOMAIN}"
            print_info "E-posta: ${ssl_email}"

            if confirm_action "SSL sertifikası alınsın mı?"; then
                echo ""
                # Nginx ile sertifika al
                certbot --nginx \
                    -d "$DOMAIN" \
                    --email "$ssl_email" \
                    --agree-tos \
                    --non-interactive \
                    --redirect \
                    2>&1 | while read -r line; do echo "  $line"; done

                if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
                    print_success "SSL sertifikası başarıyla alındı!"
                    print_info "Site artık HTTPS üzerinden erişilebilir: https://${DOMAIN}"

                    # .env'de APP_URL güncelle
                    if [[ -f "${APP_DIR}/.env" ]]; then
                        sed -i "s|^APP_URL=.*|APP_URL=https://${DOMAIN}|" "${APP_DIR}/.env"
                        print_info ".env dosyasında APP_URL güncellendi."
                    fi

                    log_action "SSL sertifikası alındı: ${DOMAIN}" "SUCCESS"
                else
                    print_error "SSL sertifikası alınamadı!"
                    print_info "DNS ayarlarınızın doğru olduğundan emin olun."
                    log_action "SSL sertifikası alınamadı: ${DOMAIN}" "ERROR"
                fi
            fi
            ;;
        2)
            print_subheader "Sertifika Yenileniyor"
            certbot renew 2>&1 | while read -r line; do echo "  $line"; done

            if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
                print_success "Sertifika yenileme tamamlandı."
                try_run "Nginx yeniden yükleniyor" "systemctl reload nginx"
            else
                print_error "Sertifika yenileme başarısız!"
            fi
            ;;
        3)
            print_subheader "Sertifika Durumu"

            local cert_dir="/etc/letsencrypt/live/${DOMAIN}"
            if [[ -d "$cert_dir" ]]; then
                # Sertifika bilgileri
                local expiry
                expiry=$(openssl x509 -enddate -noout -in "${cert_dir}/fullchain.pem" 2>/dev/null | cut -d'=' -f2)
                local issuer
                issuer=$(openssl x509 -issuer -noout -in "${cert_dir}/fullchain.pem" 2>/dev/null | sed 's/issuer= //')

                print_table_row "Domain:" "$DOMAIN" "$GREEN"
                print_table_row "Bitiş Tarihi:" "$expiry" "$YELLOW"
                print_table_row "Sertifika Yolu:" "$cert_dir" "$GRAY"

                # Kalan gün hesapla
                local expiry_epoch
                expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo "0")
                local now_epoch
                now_epoch=$(date +%s)
                local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

                if (( days_left > 30 )); then
                    print_table_row "Kalan Gün:" "${days_left} gün ✅" "$GREEN"
                elif (( days_left > 0 )); then
                    print_table_row "Kalan Gün:" "${days_left} gün ⚠️" "$YELLOW"
                else
                    print_table_row "Kalan Gün:" "SÜRESİ DOLMUŞ ❌" "$RED"
                fi
            else
                print_warning "Bu domain için SSL sertifikası bulunamadı."
                print_info "Yeni sertifika almak için seçenek 1'i kullanın."
            fi
            ;;
        4)
            print_subheader "Otomatik Yenileme Cron"

            # Certbot timer kontrolü
            if systemctl is-active --quiet certbot.timer 2>/dev/null; then
                print_table_row "Certbot Timer:" "✅ Aktif" "$GREEN"
                systemctl status certbot.timer 2>/dev/null | grep -E "Loaded|Active|Trigger" | while read -r line; do echo "  $line"; done
            else
                print_table_row "Certbot Timer:" "❌ Devre Dışı" "$RED"

                # Crontab kontrolü
                local cron_exists
                cron_exists=$(crontab -l 2>/dev/null | grep -c "certbot" || echo "0")
                if [[ "$cron_exists" -gt 0 ]]; then
                    print_table_row "Crontab:" "✅ Mevcut" "$GREEN"
                else
                    print_warning "Otomatik yenileme yapılandırılmamış!"
                    if confirm_action "Otomatik yenileme cron'u eklensin mi?"; then
                        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
                        print_success "Otomatik yenileme cron'u eklendi (her gün 03:00)."
                    fi
                fi
            fi
            ;;
        5)
            print_subheader "Yenileme Testi (Dry Run)"
            certbot renew --dry-run 2>&1 | while read -r line; do echo "  $line"; done

            if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
                print_success "Yenileme testi başarılı! Otomatik yenileme çalışacaktır."
            else
                print_error "Yenileme testi başarısız! Konfigürasyonu kontrol edin."
            fi
            ;;
        0)
            return
            ;;
    esac

    print_completion "SSL Yönetimi" "$start_time"
}

main "$@"
