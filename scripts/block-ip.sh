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

    require_root

    if ! command -v ufw &> /dev/null; then
        print_error "UFW kurulu değil!"
        if confirm_action "UFW'yi kurmak ister misiniz?"; then
            try_run "UFW kuruluyor" "apt-get install -y ufw"
        else
            return
        fi
    fi

    while true; do
        clear
        print_header "IP Engelleme / Güvenlik Duvarı"
        print_banner

        # UFW durumu
        print_subheader "Güvenlik Duvarı Durumu"
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        print_table_row "UFW:" "$ufw_status" "$WHITE"

        echo ""
        echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
        echo ""
        echo -e "  ${WHITE}1)${NC} IP engelle"
        echo -e "  ${WHITE}2)${NC} IP engelini kaldır"
        echo -e "  ${WHITE}3)${NC} Engelli IP'leri listele"
        echo -e "  ${WHITE}4)${NC} Belirli porta IP engelle"
        echo -e "  ${WHITE}5)${NC} Nginx ile IP engelle"
        echo -e "  ${WHITE}6)${NC} Şüpheli IP'leri göster (access log)"
        echo -e "  ${WHITE}7)${NC} UFW'yi etkinleştir/devre dışı bırak"
        echo -e "  ${WHITE}8)${NC} UFW kurallarını göster"
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
                read_required "Engellenecek IP adresi" block_ip
                if validate_ip "$block_ip"; then
                    try_run "IP engelleniyor: ${block_ip}" "ufw deny from ${block_ip}"
                    log_action "IP engellendi (UFW): ${block_ip}" "WARNING"
                else
                    print_error "Geçersiz IP adresi!"
                fi
                ;;
            2)
                read_required "Engeli kaldırılacak IP adresi" unblock_ip
                if validate_ip "$unblock_ip"; then
                    try_run "IP engeli kaldırılıyor: ${unblock_ip}" "ufw delete deny from ${unblock_ip}"
                    log_action "IP engeli kaldırıldı (UFW): ${unblock_ip}" "INFO"
                else
                    print_error "Geçersiz IP adresi!"
                fi
                ;;
            3)
                print_subheader "Engellenen IP'ler"
                echo -e "  ${BOLD}${CYAN}UFW ile Engellenenler:${NC}"
                ufw status numbered 2>/dev/null | grep "DENY" | while read -r line; do echo "  $line"; done

                echo ""
                echo -e "  ${BOLD}${CYAN}Nginx ile Engellenenler:${NC}"
                local nginx_block_file="/etc/nginx/conf.d/blocked_ips.conf"
                if [[ -f "$nginx_block_file" ]]; then
                    cat "$nginx_block_file" | while read -r line; do echo "  $line"; done
                else
                    print_info "Nginx bazlı engellenen IP yok."
                fi
                ;;
            4)
                read_required "Engellenecek IP adresi" port_block_ip
                read_required "Port numarası (örn: 22, 80, 3306)" block_port

                if validate_ip "$port_block_ip"; then
                    try_run "Port ${block_port} için IP engelleniyor: ${port_block_ip}" \
                        "ufw deny from ${port_block_ip} to any port ${block_port}"
                    log_action "IP porta engellendi: ${port_block_ip}:${block_port}" "WARNING"
                else
                    print_error "Geçersiz IP adresi!"
                fi
                ;;
            5)
                print_subheader "Nginx ile IP Engelleme"
                local nginx_block_file="/etc/nginx/conf.d/blocked_ips.conf"

                read_required "Nginx'te engellenecek IP" nginx_block_ip
                if validate_ip "$nginx_block_ip"; then
                    if grep -q "deny ${nginx_block_ip};" "$nginx_block_file" 2>/dev/null; then
                        print_warning "Bu IP zaten Nginx'te engelli!"
                    else
                        echo "deny ${nginx_block_ip};" >> "$nginx_block_file"
                        print_success "IP Nginx block listesine eklendi: ${nginx_block_ip}"

                        if nginx -t 2>/dev/null; then
                            systemctl reload nginx
                            print_success "Nginx yeniden yüklendi."
                        else
                            sed -i "/deny ${nginx_block_ip};/d" "$nginx_block_file"
                            print_error "Nginx testi başarısız! Değişiklik geri alındı."
                        fi
                    fi
                else
                    print_error "Geçersiz IP adresi!"
                fi
                ;;
            6)
                print_subheader "Şüpheli IP Analizi (Access Log)"

                local access_log="/var/log/nginx/access.log"
                if [[ -f "$access_log" ]]; then
                    print_info "En çok istek yapan ilk 15 IP adresi:"
                    echo ""

                    awk '{print $1}' "$access_log" 2>/dev/null | sort | uniq -c | sort -nr | head -15 | while read -r count ip; do
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
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                continue
                ;;
        esac

        press_enter_to_continue
    done

    print_completion "IP Engelleme" "$start_time"
}

main "$@"
