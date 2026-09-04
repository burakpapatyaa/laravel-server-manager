#!/bin/bash
# ============================================================================
# Laravel Server Manager — MySQL Bağlantı Yönetimi (fix-mysql-connections.sh)
# ============================================================================
# Kullanım: sudo bash scripts/fix-mysql-connections.sh
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

load_config
enable_error_trap

main() {
    local start_time
    start_time=$(date +%s)

    print_header "🔌 MySQL Bağlantı Yönetimi"
    print_banner

    # MySQL durumu
    print_subheader "MySQL Durumu"
    local mysql_status
    mysql_status=$(check_service_status "mysql")
    printf "  %-25s %b\n" "MySQL Server:" "$mysql_status"

    # Bağlantı bilgileri
    local max_conn
    max_conn=$(mysql -e "SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null | awk 'NR==2 {print $2}' || echo "Bilinmiyor")
    local current_conn
    current_conn=$(mysql -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | awk 'NR==2 {print $2}' || echo "Bilinmiyor")

    print_table_row "Max Bağlantı:" "$max_conn" "$WHITE"
    print_table_row "Aktif Bağlantı:" "$current_conn" "$YELLOW"

    echo ""
    echo -e "  ${BOLD}${CYAN}Ne yapmak istiyorsunuz?${NC}"
    echo ""
    echo -e "  ${WHITE}1)${NC} Aktif bağlantıları göster"
    echo -e "  ${WHITE}2)${NC} Uzun süren sorguları göster"
    echo -e "  ${WHITE}3)${NC} Belirli bir bağlantıyı sonlandır (ID ile)"
    echo -e "  ${WHITE}4)${NC} Max connections değerini değiştir"
    echo -e "  ${WHITE}5)${NC} MySQL performans istatistikleri"
    echo -e "  ${WHITE}6)${NC} MySQL servisini yeniden başlat"
    echo -e "  ${WHITE}7)${NC} Veritabanı boyutlarını göster"
    echo -e "  ${WHITE}0)${NC} ← Geri Dön"

    local choice
    choice=$(read_menu_choice)

    echo ""

    case "$choice" in
        1)
            print_subheader "Aktif MySQL Bağlantıları"
            mysql -e "SHOW PROCESSLIST;" 2>/dev/null || print_error "MySQL'e bağlanılamadı!"
            ;;
        2)
            print_subheader "Uzun Süren Sorgular (10+ saniye)"
            mysql -e "SELECT ID, USER, HOST, DB, COMMAND, TIME, STATE, LEFT(INFO, 80) AS QUERY FROM information_schema.PROCESSLIST WHERE TIME > 10 ORDER BY TIME DESC;" 2>/dev/null || print_error "MySQL'e bağlanılamadı!"
            ;;
        3)
            read_required "Sonlandırılacak bağlantı ID" conn_id
            if confirm_action "Bağlantı #${conn_id} sonlandırılacak. Emin misiniz?"; then
                mysql -e "KILL ${conn_id};" 2>/dev/null && print_success "Bağlantı #${conn_id} sonlandırıldı." || print_error "Bağlantı sonlandırılamadı!"
            fi
            ;;
        4)
            read_required "Yeni max_connections değeri" new_max "$max_conn"
            mysql -e "SET GLOBAL max_connections = ${new_max};" 2>/dev/null && print_success "max_connections = ${new_max} olarak ayarlandı." || print_error "Değer güncellenemedi!"
            print_warning "Bu değişiklik MySQL yeniden başlatıldığında kaybolur. Kalıcı yapmak için my.cnf düzenleyin."
            ;;
        5)
            print_subheader "MySQL Performans İstatistikleri"
            local stats=(
                "Threads_connected"
                "Threads_running"
                "Threads_created"
                "Connections"
                "Aborted_connects"
                "Aborted_clients"
                "Slow_queries"
                "Questions"
                "Uptime"
            )

            for stat in "${stats[@]}"; do
                local val
                val=$(mysql -e "SHOW GLOBAL STATUS LIKE '${stat}';" 2>/dev/null | awk 'NR==2 {print $2}' || echo "Bilinmiyor")
                print_table_row "${stat}:" "$val" "$WHITE"
            done
            ;;
        6)
            if confirm_action "MySQL yeniden başlatılacak. Devam?"; then
                restart_service "mysql"
            fi
            ;;
        7)
            print_subheader "Veritabanı Boyutları"
            mysql -e "SELECT table_schema AS 'Veritabanı', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Boyut (MB)' FROM information_schema.tables GROUP BY table_schema ORDER BY SUM(data_length + index_length) DESC;" 2>/dev/null || print_error "MySQL'e bağlanılamadı!"
            ;;
        0)
            return
            ;;
    esac

    log_action "MySQL bağlantı yönetimi (Seçim: ${choice})." "INFO"

    print_completion "MySQL Bağlantı Yönetimi" "$start_time"
}

main "$@"
