#!/bin/bash
# ============================================================================
# Laravel Server Manager — Güvenlik Taraması (fix-security.sh)
# ============================================================================
# Kullanım: sudo bash scripts/fix-security.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

# ============================================================================
# GÜVENLİK KONTROLLERİ
# ============================================================================

check_firewall() {
    print_subheader "🛡️ Güvenlik Duvarı (UFW)"

    if command -v ufw &> /dev/null; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1 || echo "Bilinmiyor")
        print_table_row "UFW Durumu:" "$ufw_status" "$WHITE"

        if [[ "$ufw_status" == *"active"* ]]; then
            print_table_row "Durum:" "✅ Aktif" "$GREEN"
            echo ""
            ufw status numbered 2>/dev/null | while read -r line; do echo "  $line"; done
        else
            print_table_row "Durum:" "❌ Devre Dışı" "$RED"
            print_warning "Güvenlik duvarı aktif değil! Etkinleştirmek önerilir."
        fi
    else
        print_table_row "UFW:" "❌ Kurulu Değil" "$RED"
    fi
}

check_open_ports() {
    print_subheader "🔓 Açık Portlar"
    ss -tulpn 2>/dev/null | head -25 | while read -r line; do echo "  $line"; done
}

check_ssh_security() {
    print_subheader "🔐 SSH Güvenliği"

    local sshd_config="/etc/ssh/sshd_config"
    if [[ -f "$sshd_config" ]]; then
        # Root login kontrolü
        local root_login
        root_login=$(grep -i "^PermitRootLogin" "$sshd_config" 2>/dev/null | awk '{print $2}' || echo "Ayarlanmamış")
        if [[ "$root_login" == "no" ]]; then
            print_table_row "Root Login:" "no ✅" "$GREEN"
        else
            print_table_row "Root Login:" "${root_login} ⚠️" "$YELLOW"
        fi

        # SSH port
        local ssh_port
        ssh_port=$(grep -i "^Port" "$sshd_config" 2>/dev/null | awk '{print $2}' || echo "22 (varsayılan)")
        if [[ "$ssh_port" == "22" || "$ssh_port" == "22 (varsayılan)" ]]; then
            print_table_row "SSH Port:" "${ssh_port} ⚠️" "$YELLOW"
            print_info "Varsayılan SSH portu kullanılıyor. Değiştirmek güvenliği artırır."
        else
            print_table_row "SSH Port:" "${ssh_port} ✅" "$GREEN"
        fi

        # Password authentication
        local pass_auth
        pass_auth=$(grep -i "^PasswordAuthentication" "$sshd_config" 2>/dev/null | awk '{print $2}' || echo "Ayarlanmamış")
        if [[ "$pass_auth" == "no" ]]; then
            print_table_row "Şifre ile Giriş:" "Devre dışı ✅" "$GREEN"
        else
            print_table_row "Şifre ile Giriş:" "Aktif ⚠️" "$YELLOW"
        fi
    else
        print_warning "SSH konfigürasyon dosyası bulunamadı."
    fi
}

check_laravel_security() {
    print_subheader "⚙️ Laravel Güvenliği"

    if [[ -f "${APP_DIR}/.env" ]]; then
        # APP_DEBUG kontrolü
        local app_debug
        app_debug=$(grep "^APP_DEBUG=" "${APP_DIR}/.env" 2>/dev/null | cut -d'=' -f2)
        if [[ "$app_debug" == "false" ]]; then
            print_table_row "APP_DEBUG:" "false ✅" "$GREEN"
        else
            print_table_row "APP_DEBUG:" "${app_debug} ⚠️ KRİTİK!" "$RED"
            print_error "Production'da APP_DEBUG=true güvenlik açığıdır!"
        fi

        # APP_ENV kontrolü
        local app_env
        app_env=$(grep "^APP_ENV=" "${APP_DIR}/.env" 2>/dev/null | cut -d'=' -f2)
        if [[ "$app_env" == "production" ]]; then
            print_table_row "APP_ENV:" "production ✅" "$GREEN"
        else
            print_table_row "APP_ENV:" "${app_env} ⚠️" "$YELLOW"
        fi

        # .env dosya izni
        local env_perms
        env_perms=$(stat -c "%a" "${APP_DIR}/.env" 2>/dev/null || echo "Bilinmiyor")
        if [[ "$env_perms" == "640" || "$env_perms" == "600" ]]; then
            print_table_row ".env İzinleri:" "${env_perms} ✅" "$GREEN"
        else
            print_table_row ".env İzinleri:" "${env_perms} ⚠️" "$YELLOW"
            print_warning ".env dosyası çok açık izinlere sahip! (önerilen: 640)"
        fi

        # .env web erişim kontrolü
        if [[ -n "$DOMAIN" ]]; then
            local env_check
            env_check=$(curl -sI "http://${DOMAIN}/.env" 2>/dev/null | head -1 || echo "")
            if [[ "$env_check" == *"404"* || "$env_check" == *"403"* ]]; then
                print_table_row ".env Web Erişim:" "Engelli ✅" "$GREEN"
            elif [[ -n "$env_check" ]]; then
                print_table_row ".env Web Erişim:" "ERİŞİLEBİLİR ❌ KRİTİK!" "$RED"
                print_error ".env dosyası web üzerinden erişilebilir durumda!"
            fi
        fi
    else
        print_warning ".env dosyası bulunamadı."
    fi
}

check_fail2ban() {
    print_subheader "🚫 Fail2Ban"

    if command -v fail2ban-client &> /dev/null; then
        local f2b_status
        f2b_status=$(check_service_status "fail2ban")
        printf "  %-25s %b\n" "Fail2Ban:" "$f2b_status"

        # Aktif jail'ler
        fail2ban-client status 2>/dev/null | while read -r line; do echo "  $line"; done
    else
        print_table_row "Fail2Ban:" "❌ Kurulu Değil" "$RED"
        print_info "Fail2Ban kurmak için: sudo apt install fail2ban"
    fi
}

show_recommendations() {
    print_subheader "💡 Güvenlik Önerileri"

    local recommendations=()

    # UFW kontrolü
    local ufw_active
    ufw_active=$(ufw status 2>/dev/null | grep -c "active" || echo "0")
    if [[ "$ufw_active" == "0" ]]; then
        recommendations+=("Güvenlik duvarını (UFW) etkinleştirin")
    fi

    # Fail2Ban kontrolü
    if ! command -v fail2ban-client &> /dev/null; then
        recommendations+=("Fail2Ban kurun: sudo apt install fail2ban")
    fi

    # APP_DEBUG kontrolü
    local app_debug
    app_debug=$(grep "^APP_DEBUG=" "${APP_DIR}/.env" 2>/dev/null | cut -d'=' -f2)
    if [[ "$app_debug" != "false" ]]; then
        recommendations+=("APP_DEBUG=false yapın (production)")
    fi

    if [[ ${#recommendations[@]} -eq 0 ]]; then
        print_success "Temel güvenlik kontrolleri geçildi! 🎉"
    else
        for rec in "${recommendations[@]}"; do
            echo -e "  ${YELLOW}  •${NC} ${WHITE}${rec}${NC}"
        done
    fi
}

# ============================================================================
# ANA AKIŞ
# ============================================================================

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🔐 Güvenlik Taraması"
    print_banner

    check_firewall
    check_open_ports
    check_ssh_security
    check_laravel_security
    check_fail2ban
    show_recommendations

    log_action "Güvenlik taraması yapıldı. Proje: ${APP_NAME}" "INFO"

    echo ""
    print_separator
    echo -e "  ${GRAY}Tarama tarihi: $(timestamp)${NC}"

    print_completion "Güvenlik Taraması" "$start_time"
}

main "$@"
