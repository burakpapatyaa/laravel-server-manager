#!/bin/bash
# ============================================================================
# Laravel Server Manager — IP Engelleme / Güvenlik Duvarı (block-ip.sh)
# ============================================================================
# Kullanım: sudo bash scripts/block-ip.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🛡️ IP Engelleme / Güvenlik Duvarı"
    print_banner

    require_root

    # UFW durumu
    print_subheader "Güvenlik Duvarı Durumu"
    if command -v ufw &> /dev/null; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        print_table_row "UFW:" "$ufw_status" "$WHITE"
    else
        print_error "UFW kurulu değil!"
        if confirm_action "UFW'yi kurmak ister misiniz?"; then
            try_run "UFW kuruluyor" "apt-get install -y ufw"
        else
            return
        fi
    fi

    echo ""
    echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} 🚫 IP engelle"
    echo -e "  ${WHITE}2)${NC} ✅ IP engelini kaldır"
    echo -e "  ${WHITE}3)${NC} 📋 Engelli IP'leri listele"
    echo -e "  ${WHITE}4)${NC} 🔒 Belirli porta IP engelle"
    echo -e "  ${WHITE}5)${NC} 🌐 Nginx ile IP engelle"
    echo -e "  ${WHITE}6)${NC} 🔍 Şüpheli IP'leri göster (access log)"
    echo -e "  ${WHITE}7)${NC} 🛡️  UFW'yi etkinleştir/devre dışı bırak"
    echo -e "  ${WHITE}8)${NC} 📊 UFW kurallarını göster"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    case "$choice" in
        1)
            read_required "Engellenecek IP adresi" block_ip
            if validate_ip "$block_ip"; then
                try_run "IP engelleniyor: ${block_ip}" "ufw deny from ${block_ip}"
                print_success "${block_ip} engellendi."
                log_action "IP engellendi: ${block_ip}" "SECURITY"
            else
                print_error "Geçersiz IP adresi!"
            fi
            ;;
        2)
            # Mevcut kuralları göster
            print_subheader "Mevcut UFW Kuralları"
            ufw status numbered 2>/dev/null | while read -r line; do echo "  $line"; done

            echo ""
            read_required "Kaldırılacak kural numarası" rule_num
            if confirm_action "Kural #${rule_num} kaldırılacak. Emin misiniz?"; then
                echo "y" | ufw delete "$rule_num" 2>/dev/null
                print_success "Kural #${rule_num} kaldırıldı."
                log_action "UFW kuralı kaldırıldı: #${rule_num}" "SECURITY"
            fi
            ;;
        3)
            print_subheader "Engelli IP Kuralları"
            ufw status 2>/dev/null | grep "DENY" | while read -r line; do echo "  ${RED}${line}${NC}"; done

            local deny_count
            deny_count=$(ufw status 2>/dev/null | grep -c "DENY" || echo "0")
            echo ""
            print_info "Toplam ${deny_count} engelleme kuralı."
            ;;
        4)
            read_required "Engellenecek IP adresi" block_ip
            if ! validate_ip "$block_ip"; then
                print_error "Geçersiz IP adresi!"
                return
            fi

            read_required "Port numarası (örn: 80, 443, 3306)" block_port
            try_run "IP porta engelleniyor: ${block_ip}:${block_port}" "ufw deny from ${block_ip} to any port ${block_port}"
            print_success "${block_ip} → port ${block_port} engellendi."
            log_action "IP porta engellendi: ${block_ip}:${block_port}" "SECURITY"
            ;;
        5)
            print_subheader "Nginx ile IP Engelleme"

            read_required "Engellenecek IP adresi" block_ip
            if ! validate_ip "$block_ip"; then
                print_error "Geçersiz IP adresi!"
                return
            fi

            local nginx_conf="/etc/nginx/sites-available/${APP_NAME}"
            if [[ -f "$nginx_conf" ]]; then
                # server bloğunun içine deny ekle
                if grep -q "deny ${block_ip}" "$nginx_conf"; then
                    print_warning "Bu IP zaten Nginx'te engelli."
                else
                    sed -i "/server_name/a\\    deny ${block_ip};" "$nginx_conf"

                    if nginx -t 2>/dev/null; then
                        try_run "Nginx yeniden yükleniyor" "systemctl reload nginx"
                        print_success "${block_ip} Nginx üzerinden engellendi."
                    else
                        # Geri al
                        sed -i "/deny ${block_ip}/d" "$nginx_conf"
                        print_error "Nginx konfigürasyon hatası! Değişiklik geri alındı."
                    fi
                fi
            else
                print_error "Nginx vhost dosyası bulunamadı: ${nginx_conf}"
            fi
            ;;
        6)
            print_subheader "Şüpheli IP'ler (En Çok İstek Yapanlar)"

            local access_log="/var/log/nginx/access.log"
            if [[ -f "$access_log" ]]; then
                echo -e "  ${GRAY}İstek  IP Adresi${NC}"
                print_separator
                awk '{print $1}' "$access_log" 2>/dev/null | sort | uniq -c | sort -rn | head -20 | while read -r count ip; do
                    if (( count > 1000 )); then
                        printf "  ${RED}%-7s %s${NC}\n" "$count" "$ip"
                    elif (( count > 500 )); then
                        printf "  ${YELLOW}%-7s %s${NC}\n" "$count" "$ip"
                    else
                        printf "  ${WHITE}%-7s %s${NC}\n" "$count" "$ip"
                    fi
                done

                echo ""
                print_info "Kırmızı: 1000+ istek, Sarı: 500+ istek"
            else
                print_warning "Nginx access log bulunamadı."
            fi
            ;;
        7)
            local ufw_active
            ufw_active=$(ufw status 2>/dev/null | head -1)

            if [[ "$ufw_active" == *"active"* ]]; then
                if confirm_action "⚠️  UFW devre dışı bırakılacak. Emin misiniz?" "h"; then
                    ufw disable 2>/dev/null
                    print_success "UFW devre dışı bırakıldı."
                fi
            else
                if confirm_action "UFW etkinleştirilecek. Devam?"; then
                    echo "y" | ufw enable 2>/dev/null
                    print_success "UFW etkinleştirildi."
                fi
            fi
            ;;
        8)
            print_subheader "UFW Kuralları"
            ufw status verbose 2>/dev/null | while read -r line; do echo "  $line"; done
            ;;
        0)
            return
            ;;
    esac

    print_completion "IP Engelleme" "$start_time"
}

main "$@"
