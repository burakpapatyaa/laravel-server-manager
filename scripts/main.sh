#!/bin/bash
# ============================================================================
# Laravel Server Manager — Ana İnteraktif Yönetim Paneli (main.sh)
# ============================================================================
# Kullanım: bash scripts/main.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Config kontrolü — yoksa kuruluma yönlendir
if ! check_config; then
    echo ""
    print_warning "Config dosyası bulunamadı!"
    print_info "İlk kurulum henüz yapılmamış. Kurulum sihirbazı başlatılıyor..."
    echo ""
    if confirm_action "Kurulum sihirbazını başlatmak istiyor musunuz?"; then
        exec sudo bash "${SCRIPT_DIR}/install.sh"
    else
        print_info "Manuel kurulum için: ${BOLD}sudo bash ${SCRIPT_DIR}/install.sh${NC}"
        exit 0
    fi
fi

# Config yükle
load_config

# Error trap
enable_error_trap

# ============================================================================
# FONKSİYONLAR
# ============================================================================

# Hızlı sistem bilgisi
quick_system_info() {
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null || echo "Bilinmiyor")
    local disk_usage
    disk_usage=$(df -h / 2>/dev/null | awk 'NR==2 {print $5 " kullanılıyor (" $3 "/" $2 ")"}' || echo "Bilinmiyor")
    local mem_usage
    mem_usage=$(free -h 2>/dev/null | awk 'NR==2 {printf "%s / %s", $3, $2}' || echo "Bilinmiyor")

    echo -e "  ${GRAY}Uptime: ${WHITE}${uptime_str}${NC}  ${GRAY}│${NC}  ${GRAY}Disk: ${WHITE}${disk_usage}${NC}  ${GRAY}│${NC}  ${GRAY}RAM: ${WHITE}${mem_usage}${NC}"
}

# Ana menü
show_menu() {
    clear
    print_banner

    # Hızlı sistem bilgisi
    quick_system_info
    echo ""
    print_separator

    echo ""
    echo -e "  ${BOLD}${WHITE}  Menü${NC}"
    echo ""
    echo -e "  ${CYAN} 0)${NC}  Sistem Durumu"
    echo -e "  ${CYAN} 1)${NC}  Deploy / Güncelleme"
    echo -e "  ${CYAN} 2)${NC}  Ayarları Yönet / Değiştir"
    echo ""
    echo -e "  ${CYAN} 3)${NC}  Servisleri Yeniden Başlat"
    echo -e "  ${CYAN} 4)${NC}  Dosya İzinlerini Düzelt"
    echo -e "  ${CYAN} 5)${NC}  Laravel Cache Temizle / Yenile"
    echo -e "  ${CYAN} 6)${NC}  Storage Symlink Onar"
    echo -e "  ${CYAN} 7)${NC}  Queue Worker Yönetimi"
    echo -e "  ${CYAN} 8)${NC}  Başarısız Job'ları Yönet"
    echo ""
    echo -e "  ${CYAN} 9)${NC}  Disk Alanını Temizle"
    echo -e "  ${CYAN}10)${NC}  Veritabanı Yedeği Al"
    echo -e "  ${CYAN}11)${NC}  Yedekten Geri Yükle"
    echo ""
    echo -e "  ${CYAN}12)${NC}  SSL Kurulumu (Let's Encrypt)"
    echo -e "  ${CYAN}13)${NC}  IP Engelle / Güvenlik Duvarı"
    echo -e "  ${CYAN}14)${NC}  Güvenlik Taraması"
    echo ""
    echo -e "  ${CYAN}15)${NC}  MySQL Bağlantı Yönetimi"
    echo -e "  ${CYAN}16)${NC}  Nginx Yönetimi"
    echo -e "  ${CYAN}17)${NC}  Session Yönetimi"
    echo -e "  ${CYAN}18)${NC}  PHP Sürüm Değiştir / Yükselt"
    echo -e "  ${CYAN}19)${NC}  Log Görüntüleyici & Hata Teşhis"
    echo ""
    echo -e "  ${YELLOW} n)${NC}  Yeni Kurulum (Yeni Proje Ekle)"
    echo -e "  ${YELLOW} p)${NC}  Proje Değiştir"
    echo -e "  ${YELLOW} q)${NC}  Çıkış"
    echo ""
}

# Seçimi çalıştır
execute_choice() {
    local choice="$1"

    case "$choice" in
        0)  bash "${SCRIPT_DIR}/status.sh" ;;
        1)  bash "${SCRIPT_DIR}/deploy.sh" ;;
        2)  bash "${SCRIPT_DIR}/settings.sh" ;;
        3)  bash "${SCRIPT_DIR}/fix-services.sh" ;;
        4)  bash "${SCRIPT_DIR}/fix-permissions.sh" ;;
        5)  bash "${SCRIPT_DIR}/fix-laravel-cache.sh" ;;
        6)  bash "${SCRIPT_DIR}/fix-storage.sh" ;;
        7)  bash "${SCRIPT_DIR}/fix-queue.sh" ;;
        8)  bash "${SCRIPT_DIR}/fix-failed-jobs.sh" ;;
        9)  bash "${SCRIPT_DIR}/fix-disk.sh" ;;
        10) bash "${SCRIPT_DIR}/backup-db.sh" ;;
        11) bash "${SCRIPT_DIR}/restore-db.sh" ;;
        12) bash "${SCRIPT_DIR}/setup-ssl.sh" ;;
        13) bash "${SCRIPT_DIR}/block-ip.sh" ;;
        14) bash "${SCRIPT_DIR}/fix-security.sh" ;;
        15) bash "${SCRIPT_DIR}/fix-mysql-connections.sh" ;;
        16) bash "${SCRIPT_DIR}/fix-nginx-version.sh" ;;
        17) bash "${SCRIPT_DIR}/fix-sessions.sh" ;;
        18) bash "${SCRIPT_DIR}/switch-php.sh" ;;
        19) bash "${SCRIPT_DIR}/view-logs.sh" ;;
        q|Q)
            echo ""
            print_info "Laravel Server Manager kapatılıyor..."
            echo -e "  ${GRAY}İyi çalışmalar!${NC}"
            echo ""
            exit 0
            ;;
        *)
            print_warning "Geçersiz seçim! Lütfen menüden bir seçenek girin."
            sleep 1
            return 1
            ;;
    esac
    return 0
}

# ============================================================================
# ANA AKIŞ
# ============================================================================

main() {
    while true; do
        show_menu
        local choice
        choice=$(read_menu_choice)

        # Boş girildiyse menüyü yenile
        [[ -z "$choice" ]] && continue

        if execute_choice "$choice"; then
            # Sadece tek seferlik (sub-menüsü olmayan) işlemlerden sonra Enter bekle
            case "$choice" in
                0|1|4|6|14)
                    press_enter_to_continue
                    ;;
            esac
        fi
    done
}

main "$@"
