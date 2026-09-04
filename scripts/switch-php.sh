#!/bin/bash
# ============================================================================
# Laravel Server Manager — PHP Sürüm Değiştirme ve Yükseltme (switch-php.sh)
# ============================================================================
# Kullanım: bash scripts/switch-php.sh [hedef_surum]
# Örnek:    bash scripts/switch-php.sh 8.3
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

# Sudo komutunu belirle
get_sudo_cmd() {
    if [[ $EUID -ne 0 ]]; then
        echo "sudo"
    else
        echo ""
    fi
}

# Sudo yetkisini doğrula
ensure_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_step "Sudo yetkisi kontrol ediliyor..."
        if ! sudo -v; then
            print_error "Bu işlem sistem düzeyinde paket kurulumu ve servis yönetimi için sudo yetkisi gerektirir!"
            return 1
        fi
    fi
    return 0
}

# Mevcut PHP durumunu göster
show_php_status() {
    print_subheader "Mevcut PHP Durumu"

    local current_cli
    current_cli=$(php -r 'echo PHP_VERSION;' 2>/dev/null || php -v 2>/dev/null | head -n 1 | awk '{print $2}' || echo "Yüklü değil")
    
    local active_fpms
    active_fpms=$(systemctl list-units --type=service --state=running 2>/dev/null | grep -oE "php[0-9]+\.[0-9]+-fpm" | tr '\n' ' ' || echo "Yok")
    [[ -z "$active_fpms" ]] && active_fpms="Çalışan FPM servisi bulunamadı"

    local nginx_socket="Bilinmiyor"
    local vhost_file="/etc/nginx/sites-available/${APP_NAME}"
    if [[ -f "$vhost_file" ]]; then
        nginx_socket=$(grep -oE "fastcgi_pass.+;" "$vhost_file" 2>/dev/null | head -1 | tr -d ';' | awk '{print $2}' || echo "Bulunamadı")
    fi

    print_table_row "Config PHP Sürümü:" "$PHP_VERSION" "$YELLOW"
    print_table_row "CLI Varsayılan PHP:" "$current_cli" "$WHITE"
    print_table_row "Aktif PHP-FPM Servisleri:" "$active_fpms" "$CYAN"
    print_table_row "Nginx FastCGI Soketi:" "$nginx_socket" "$WHITE"
}

# PHP Yükseltme ve Geçiş Fonksiyonu
do_switch_php() {
    local target_version="$1"
    local old_version="${PHP_VERSION:-8.2}"
    local start_time
    start_time=$(date +%s)
    local sudo_cmd
    sudo_cmd=$(get_sudo_cmd)

    echo ""
    print_header "🐘 PHP ${target_version} Geçişi Başlatılıyor"
    print_step "Hedef Sürüm: PHP ${target_version} (Eski Sürüm: ${old_version})"

    # 1. Paketlerin kurulu olup olmadığını kontrol et
    local packages_needed=0
    if ! dpkg -s "php${target_version}-fpm" >/dev/null 2>&1 || ! command -v "php${target_version}" >/dev/null 2>&1; then
        packages_needed=1
    fi

    if [[ $packages_needed -eq 1 ]]; then
        print_step "PHP ${target_version} paketleri indirilecek ve kurulacak..."

        # PPA kontrolü
        if ! grep -rq "ondrej/php" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
            try_run "Yazılım özellikleri aracı kuruluyor" "$sudo_cmd apt-get install -y software-properties-common"
            try_run "Ondřej Surý PHP PPA deposu ekleniyor" "$sudo_cmd add-apt-repository -y ppa:ondrej/php"
        fi

        try_run "Paket listesi güncelleniyor (apt update)" "$sudo_cmd apt-get update -y"

        local php_packages=(
            "php${target_version}"
            "php${target_version}-fpm"
            "php${target_version}-cli"
            "php${target_version}-common"
            "php${target_version}-mysql"
            "php${target_version}-pgsql"
            "php${target_version}-sqlite3"
            "php${target_version}-curl"
            "php${target_version}-gd"
            "php${target_version}-mbstring"
            "php${target_version}-xml"
            "php${target_version}-zip"
            "php${target_version}-bcmath"
            "php${target_version}-intl"
            "php${target_version}-readline"
            "php${target_version}-tokenizer"
            "php${target_version}-redis"
            "php${target_version}-opcache"
        )

        try_run "PHP ${target_version} ve Laravel eklentileri kuruluyor" \
            "$sudo_cmd DEBIAN_FRONTEND=noninteractive apt-get install -y ${php_packages[*]}"
    else
        print_info "PHP ${target_version} ve eklentileri zaten sistemde kurulu."
    fi

    # 2. PHP-FPM servisini etkinleştir ve başlat
    try_run "PHP-FPM ${target_version} etkinleştiriliyor ve başlatılıyor" \
        "$sudo_cmd systemctl enable php${target_version}-fpm && $sudo_cmd systemctl restart php${target_version}-fpm"

    # Soketin oluşup oluşmadığını doğrula
    local socket_path="/var/run/php/php${target_version}-fpm.sock"
    local socket_alt_path="/run/php/php${target_version}-fpm.sock"
    sleep 1
    if [[ -S "$socket_path" || -S "$socket_alt_path" ]]; then
        print_success "PHP-FPM soketi hazır: ${socket_path}"
    else
        print_warning "PHP-FPM soketi henüz hazır olmayabilir. Servis durumu kontrol ediliyor..."
        $sudo_cmd systemctl status "php${target_version}-fpm" --no-pager -l || true
    fi

    # 3. CLI varsayılan PHP sürümünü güncelle
    if [[ -f "/usr/bin/php${target_version}" ]]; then
        try_run "CLI varsayılan PHP sürümü ayarlanıyor (update-alternatives)" \
            "$sudo_cmd update-alternatives --set php /usr/bin/php${target_version}"
        if [[ -f "/usr/bin/php-config${target_version}" ]]; then
            $sudo_cmd update-alternatives --set php-config "/usr/bin/php-config${target_version}" 2>/dev/null || true
        fi
        if [[ -f "/usr/bin/phpize${target_version}" ]]; then
            $sudo_cmd update-alternatives --set phpize "/usr/bin/phpize${target_version}" 2>/dev/null || true
        fi
    fi

    # 4. Nginx vhost konfigürasyonlarını güncelle
    print_step "Nginx vhost konfigürasyonları güncelleniyor..."
    local updated_vhosts=0
    local search_paths=("/etc/nginx/sites-available" "/etc/nginx/conf.d")

    for dir in "${search_paths[@]}"; do
        [[ -d "$dir" ]] || continue
        for conf in "$dir"/*; do
            [[ -f "$conf" ]] || continue
            if grep -qE "fastcgi_pass[[:space:]]+unix:/(var/)?run/php/php[0-9]+\.[0-9]+-fpm\.sock" "$conf" 2>/dev/null; then
                $sudo_cmd cp "$conf" "${conf}.bak.$(date +%s)" 2>/dev/null || true
                $sudo_cmd sed -i -E "s|fastcgi_pass[[:space:]]+unix:/(var/)?run/php/php[0-9]+\.[0-9]+-fpm\.sock;|fastcgi_pass unix:/var/run/php/php${target_version}-fpm.sock;|g" "$conf"
                updated_vhosts=$((updated_vhosts + 1))
            fi
        done
    done

    # APP_NAME vhost'u varsa doğrudan kontrol et
    local app_vhost="/etc/nginx/sites-available/${APP_NAME}"
    if [[ -f "$app_vhost" ]]; then
        if grep -q "fastcgi_pass" "$app_vhost" 2>/dev/null; then
            $sudo_cmd sed -i -E "s|fastcgi_pass[[:space:]]+unix:/(var/)?run/php/php[0-9]+\.[0-9]+-fpm\.sock;|fastcgi_pass unix:/var/run/php/php${target_version}-fpm.sock;|g" "$app_vhost"
        fi
    fi

    print_success "${updated_vhosts} adet Nginx vhost dosyası PHP ${target_version} soketine güncellendi."

    # Nginx konfigürasyonunu test et ve reload et
    print_step "Nginx testi yapılıyor (nginx -t)..."
    if $sudo_cmd nginx -t >/dev/null 2>&1; then
        try_run "Nginx yeniden yükleniyor (reload)" "$sudo_cmd systemctl reload nginx"
    else
        print_error "Nginx konfigürasyon testi başarısız oldu! Hata detayı:"
        $sudo_cmd nginx -t || true
        print_warning "Nginx yeniden yüklenemedi. Lütfen vhost dosyasını kontrol edin."
    fi

    # 5. Supervisor Queue Worker'ları yeniden başlat
    if command -v supervisorctl &>/dev/null && systemctl is-active --quiet supervisor 2>/dev/null; then
        try_run "Supervisor Queue Worker'lar yeni PHP ile yeniden başlatılıyor" \
            "$sudo_cmd supervisorctl restart all"
    fi

    # 6. Laravel önbelleğini temizle (varsa)
    if [[ -n "$APP_DIR" && -d "$APP_DIR" && -f "$APP_DIR/artisan" ]]; then
        print_step "Laravel uygulama optimizasyonları ve önbellek yenileniyor..."
        if [[ -n "$APP_USER" && "$APP_USER" != "root" ]] && id "$APP_USER" &>/dev/null; then
            su -s /bin/bash "$APP_USER" -c "cd '$APP_DIR' && php artisan optimize:clear" >/dev/null 2>&1 || true
        else
            (cd "$APP_DIR" && php artisan optimize:clear >/dev/null 2>&1 || true)
        fi
        print_success "Laravel önbelleği temizlendi."
    fi

    # 7. Config dosyasını güncelle
    update_config_value "PHP_VERSION" "$target_version"
    PHP_VERSION="$target_version"

    # 8. Eski PHP-FPM servisini durdurma opsiyonu
    if [[ -n "$old_version" && "$old_version" != "$target_version" ]]; then
        if systemctl is-active --quiet "php${old_version}-fpm" 2>/dev/null; then
            echo ""
            if confirm_action "Eski PHP servisi (php${old_version}-fpm) durdurulsun mu? (RAM tasarrufu sağlar)" "e"; then
                $sudo_cmd systemctl stop "php${old_version}-fpm" 2>/dev/null || true
                $sudo_cmd systemctl disable "php${old_version}-fpm" 2>/dev/null || true
                print_success "Eski PHP-FPM (${old_version}) servisi durduruldu ve devre dışı bırakıldı."
            else
                print_info "Eski PHP-FPM (${old_version}) servisi çalışır durumda bırakıldı."
            fi
        fi
    fi

    # 9. Sonuç özeti
    echo ""
    print_header "🎉 PHP Geçişi Tamamlandı"
    
    local new_cli
    new_cli=$(php -v 2>/dev/null | head -n 1 || echo "Bilinmiyor")
    local fpm_status
    fpm_status=$(check_service_status "php${target_version}-fpm")

    print_table_row "Yeni PHP Sürümü:" "$target_version" "$GREEN"
    print_table_row "CLI Sürümü:" "$new_cli" "$WHITE"
    printf "  %-25s %b\n" "PHP-FPM Durumu:" "$fpm_status"
    print_table_row "Nginx Soketi:" "unix:/var/run/php/php${target_version}-fpm.sock" "$CYAN"

    log_action "PHP sürümü ${old_version} -> ${target_version} olarak yükseltildi/değiştirildi." "SUCCESS"
    print_completion "PHP Geçişi" "$start_time"
}

# İnteraktif Menü
main() {
    # Eğer parametre verildiyse doğrudan o sürüme geç
    if [[ -n "${1:-}" ]]; then
        local target="$1"
        case "$target" in
            8.1|8.2|8.3|8.4)
                ensure_sudo || exit 1
                do_switch_php "$target"
                exit 0
                ;;
            *)
                print_error "Desteklenmeyen PHP sürümü: $target. Desteklenenler: 8.1, 8.2, 8.3, 8.4"
                exit 1
                ;;
        esac
    fi

    while true; do
        clear
        print_header "PHP Sürüm Değiştirme & Yükseltme"
        print_banner

        show_php_status

        echo ""
        echo -e "  ${BOLD}${CYAN}Hangi PHP sürümüne geçmek / yükseltmek istiyorsunuz?${NC}"
        echo ""
        echo -e "  ${WHITE}1)${NC} PHP 8.1"
        echo -e "  ${WHITE}2)${NC} PHP 8.2"
        echo -e "  ${WHITE}3)${NC} PHP 8.3"
        echo -e "  ${WHITE}4)${NC} PHP 8.4"
        echo -e "  ${WHITE}0)${NC} ← Geri Dön"
        echo ""

        local choice
        choice=$(read_menu_choice)

        [[ -z "$choice" ]] && continue

        if [[ "$choice" == "0" || "$choice" == "q" || "$choice" == "Q" ]]; then
            break
        fi

        local target_ver=""
        case "$choice" in
            1) target_ver="8.1" ;;
            2) target_ver="8.2" ;;
            3) target_ver="8.3" ;;
            4) target_ver="8.4" ;;
            *)
                print_warning "Geçersiz seçim!"
                sleep 1
                continue
                ;;
        esac

        if [[ "$target_ver" == "$PHP_VERSION" ]]; then
            echo ""
            print_warning "Sistemde zaten PHP ${target_ver} seçili."
            if ! confirm_action "Yine de paketleri kontrol edip Nginx/FPM bağlantılarını onarmak/yenilemek istiyor musunuz?" "h"; then
                continue
            fi
        else
            echo ""
            print_info "Sistemdeki PHP sürümü ${PHP_VERSION} -> ${target_ver} olarak değiştirilecek."
            print_info "Bu işlem; paket kurulumu, PHP-FPM servisi, Nginx vhost soketi ve CLI varsayılanını güncelleyecektir."
            if ! confirm_action "PHP ${target_ver} sürümüne geçişi onaylıyor musunuz?" "e"; then
                print_info "İşlem iptal edildi."
                sleep 1
                continue
            fi
        fi

        if ! ensure_sudo; then
            press_enter_to_continue
            continue
        fi

        do_switch_php "$target_ver"
        press_enter_to_continue
    done
}

main "$@"
