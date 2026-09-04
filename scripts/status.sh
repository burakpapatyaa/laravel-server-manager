#!/bin/bash
# ============================================================================
# Laravel Server Manager — Sistem Durumu (status.sh)
# ============================================================================
# Kullanım: bash scripts/status.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Config yükle
load_config

# ============================================================================
# FONKSİYONLAR
# ============================================================================

show_system_info() {
    print_subheader "🖥️ Sistem Bilgisi"

    local os_info
    os_info=$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release 2>/dev/null | grep "PRETTY_NAME" | cut -d'"' -f2 || echo "Bilinmiyor")
    local kernel
    kernel=$(uname -r 2>/dev/null || echo "Bilinmiyor")
    local hostname_str
    hostname_str=$(hostname 2>/dev/null || echo "Bilinmiyor")
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null || echo "Bilinmiyor")
    local load_avg
    load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1, $2, $3}' || echo "Bilinmiyor")

    print_table_row "İşletim Sistemi:" "$os_info" "$WHITE"
    print_table_row "Kernel:" "$kernel" "$WHITE"
    print_table_row "Hostname:" "$hostname_str" "$WHITE"
    print_table_row "Uptime:" "$uptime_str" "$GREEN"
    print_table_row "Load Average:" "$load_avg" "$YELLOW"
}

show_disk_usage() {
    print_subheader "💾 Disk Kullanımı"

    df -h / 2>/dev/null | awk 'NR==1 {printf "  %-15s %-8s %-8s %-8s %-6s\n", $1, $2, $3, $4, $5} NR==2 {printf "  %-15s %-8s %-8s %-8s %-6s\n", $1, $2, $3, $4, $5}'
    echo ""

    # Proje dizini boyutu
    if [[ -d "$APP_DIR" ]]; then
        local project_size
        project_size=$(du -sh "$APP_DIR" 2>/dev/null | awk '{print $1}' || echo "Bilinmiyor")
        print_table_row "Proje Boyutu:" "$project_size" "$WHITE"
    fi
}

show_memory_usage() {
    print_subheader "🧠 Bellek Kullanımı"

    free -h 2>/dev/null | awk 'NR==1 {printf "  %-10s %-8s %-8s %-8s\n", "", $1, $2, $3} NR==2 {printf "  %-10s %-8s %-8s %-8s\n", "RAM:", $2, $3, $4} NR==3 {printf "  %-10s %-8s %-8s %-8s\n", "Swap:", $2, $3, $4}'
}

show_service_status() {
    print_subheader "🔧 Servis Durumları"

    local services=("nginx" "mysql" "php${PHP_VERSION}-fpm" "supervisor" "redis-server" "ufw")
    local labels=("Nginx" "MySQL" "PHP-FPM ${PHP_VERSION}" "Supervisor" "Redis" "UFW Firewall")

    for i in "${!services[@]}"; do
        local status
        status=$(check_service_status "${services[$i]}")
        printf "  %-25s %b\n" "${labels[$i]}:" "$status"
    done
}

show_laravel_status() {
    print_subheader "⚙️ Laravel Durumu"

    if [[ ! -d "$APP_DIR" ]]; then
        print_warning "Proje dizini bulunamadı: ${APP_DIR}"
        return
    fi

    # .env kontrolü
    if [[ -f "${APP_DIR}/.env" ]]; then
        print_table_row ".env Dosyası:" "Mevcut ✅" "$GREEN"

        # APP_DEBUG kontrolü
        local app_debug
        app_debug=$(grep "^APP_DEBUG=" "${APP_DIR}/.env" 2>/dev/null | cut -d'=' -f2 || echo "Bilinmiyor")
        if [[ "$app_debug" == "false" ]]; then
            print_table_row "APP_DEBUG:" "false ✅" "$GREEN"
        else
            print_table_row "APP_DEBUG:" "${app_debug} ⚠️" "$YELLOW"
        fi

        # APP_ENV kontrolü
        local app_env
        app_env=$(grep "^APP_ENV=" "${APP_DIR}/.env" 2>/dev/null | cut -d'=' -f2 || echo "Bilinmiyor")
        print_table_row "APP_ENV:" "$app_env" "$WHITE"
    else
        print_table_row ".env Dosyası:" "Bulunamadı ❌" "$RED"
    fi

    # Storage link kontrolü
    if [[ -L "${APP_DIR}/public/storage" ]]; then
        print_table_row "Storage Link:" "Mevcut ✅" "$GREEN"
    else
        print_table_row "Storage Link:" "Eksik ❌" "$RED"
    fi

    # Cache durumu
    if [[ -f "${APP_DIR}/bootstrap/cache/config.php" ]]; then
        print_table_row "Config Cache:" "Var ✅" "$GREEN"
    else
        print_table_row "Config Cache:" "Yok" "$GRAY"
    fi

    if [[ -f "${APP_DIR}/bootstrap/cache/routes-v7.php" ]]; then
        print_table_row "Route Cache:" "Var ✅" "$GREEN"
    else
        print_table_row "Route Cache:" "Yok" "$GRAY"
    fi

    # Log dosyası boyutu
    if [[ -f "${APP_DIR}/storage/logs/laravel.log" ]]; then
        local log_size
        log_size=$(du -sh "${APP_DIR}/storage/logs/laravel.log" 2>/dev/null | awk '{print $1}')
        print_table_row "Laravel Log:" "$log_size" "$WHITE"
    fi
}

show_project_info() {
    print_subheader "📋 Proje Bilgileri"

    print_table_row "Proje Adı:" "$APP_NAME" "$GREEN"
    print_table_row "Dizin:" "$APP_DIR" "$WHITE"
    print_table_row "Domain:" "${DOMAIN:-Yapılandırılmadı}" "$WHITE"
    print_table_row "Sunucu IP:" "$SERVER_IP" "$WHITE"
    print_table_row "PHP Sürümü:" "$PHP_VERSION" "$YELLOW"
    print_table_row "Son Deploy:" "${DEPLOY_TIMESTAMP:-Henüz yapılmadı}" "$GRAY"

    # Git bilgisi
    if [[ -d "${APP_DIR}/.git" ]]; then
        cd "$APP_DIR"
        local current_branch
        current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "Bilinmiyor")
        local last_commit
        last_commit=$(git log -1 --format="%h - %s (%ar)" 2>/dev/null || echo "Bilinmiyor")
        print_table_row "Git Branch:" "$current_branch" "$CYAN"
        print_table_row "Son Commit:" "$last_commit" "$GRAY"
        cd - > /dev/null
    fi
}

# ============================================================================
# ANA AKIŞ
# ============================================================================

main() {
    print_header "📊 Sistem Durumu"
    print_banner

    show_project_info
    show_system_info
    show_memory_usage
    show_disk_usage
    show_service_status
    show_laravel_status

    echo ""
    print_separator
    echo -e "  ${GRAY}Rapor tarihi: $(timestamp)${NC}"
    echo ""
}

main "$@"
