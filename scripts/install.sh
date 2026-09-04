#!/bin/bash
# ============================================================================
# Laravel Server Manager — İlk Kurulum Sihirbazı (install.sh)
# ============================================================================
# Kullanım: sudo bash scripts/install.sh
# ============================================================================
# Bu script sunucuya ilk kurulumu yapar:
#   1. Kullanıcıdan interaktif bilgi alır
#   2. Gerekli paketleri kurar (PHP, Composer, MySQL, Nginx, Supervisor)
#   3. GitHub'dan repoyu klonlar
#   4. Laravel'i yapılandırır (.env, migrate, storage:link)
#   5. Nginx ve Supervisor konfigürasyonlarını oluşturur
#   6. config.sh dosyasını oluşturur
# ============================================================================

# Script dizini
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# common.sh yükle — config olmadan da çalışabilmeli
if ! source "${SCRIPT_DIR}/common.sh" 2>/dev/null; then
    # common.sh yüklenemezse yedek renk tanımları
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    BOLD='\033[1m'
    DIM='\033[2m'
    NC='\033[0m'
fi

# ============================================================================
# FONKSİYONLAR
# ============================================================================

show_welcome() {
    clear
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo -e "  ║   ${BOLD}${WHITE}🚀 Laravel Server Manager — Kurulum Sihirbazı${NC}${CYAN}        ║"
    echo -e "  ║   ${DIM}Versiyon 1.0.0${NC}${CYAN}                                        ║"
    echo "  ║                                                          ║"
    echo "  ╠══════════════════════════════════════════════════════════╣"
    echo -e "  ║  ${WHITE}Bu sihirbaz sunucunuzu Laravel için yapılandıracak.${NC}${CYAN}   ║"
    echo -e "  ║  ${WHITE}Kurulum sırasında aşağıdaki bileşenler kurulacak:${NC}${CYAN}    ║"
    echo -e "  ║                                                          ║"
    echo -e "  ║   ${GREEN}•${NC}${CYAN} PHP (seçtiğiniz sürüm) + Eklentiler              ║"
    echo -e "  ║   ${GREEN}•${NC}${CYAN} Composer (Global)                                 ║"
    echo -e "  ║   ${GREEN}•${NC}${CYAN} MySQL Server                                      ║"
    echo -e "  ║   ${GREEN}•${NC}${CYAN} Nginx Web Server                                  ║"
    echo -e "  ║   ${GREEN}•${NC}${CYAN} Supervisor (Queue Worker)                         ║"
    echo -e "  ║   ${GREEN}•${NC}${CYAN} Certbot (Let's Encrypt SSL)                       ║"
    echo -e "  ║   ${GREEN}•${NC}${CYAN} UFW Firewall                                      ║"
    echo "  ║                                                          ║"
    echo -e "  ╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Root kontrolü
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}  ❌ Bu script root yetkisi gerektirir!${NC}"
        echo -e "${CYAN}  ℹ️  Şu komutla çalıştırın: ${BOLD}sudo bash ${SCRIPT_DIR}/install.sh${NC}"
        exit 1
    fi
}

# İnteraktif bilgi toplama
collect_information() {
    print_header "📝 Proje Bilgileri"

    # Proje adı
    read_required "Proje adı (örn: my-laravel-app)" APP_NAME
    
    # Proje dizini
    local default_dir="/var/www/${APP_NAME}"
    read_required "Proje dizin yolu" APP_DIR "$default_dir"

    # Sunucu IP
    local detected_ip
    detected_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    read_required "Sunucu IP adresi" SERVER_IP "$detected_ip"

    # Domain
    read_optional "Domain adı (örn: example.com)" DOMAIN ""

    print_header "🔗 GitHub Bilgileri"

    # GitHub kullanıcı adı
    read_required "GitHub kullanıcı adı" GITHUB_USER

    # GitHub repo adı
    read_required "GitHub repo adı" GITHUB_REPO

    # Branch
    read_required "Branch adı" GITHUB_BRANCH "main"

    # Public/Private
    echo ""
    echo -e "  ${CYAN}Repo tipi:${NC}"
    echo -e "    ${WHITE}1)${NC} Public"
    echo -e "    ${WHITE}2)${NC} Private"
    echo -ne "  ${CYAN}Seçiminiz${NC} ${GRAY}[1]${NC}: "
    read -r repo_choice
    repo_choice="${repo_choice:-1}"

    if [[ "$repo_choice" == "2" ]]; then
        REPO_VISIBILITY="private"
        echo ""
        print_warning "Private repo için GitHub Personal Access Token (PAT) gereklidir."
        print_info "Token oluşturmak için: https://github.com/settings/tokens"
        read_secret "GitHub Personal Access Token (PAT)" GITHUB_TOKEN
    else
        REPO_VISIBILITY="public"
        GITHUB_TOKEN=""
    fi

    print_header "🐘 PHP Sürümü"

    echo -e "  ${CYAN}Hangi PHP sürümünü kurmak istiyorsunuz?${NC}"
    echo -e "    ${WHITE}1)${NC} PHP 8.1"
    echo -e "    ${WHITE}2)${NC} PHP 8.2 ${GREEN}(Önerilen)${NC}"
    echo -e "    ${WHITE}3)${NC} PHP 8.3"
    echo -e "    ${WHITE}4)${NC} PHP 8.4"
    echo -ne "  ${CYAN}Seçiminiz${NC} ${GRAY}[2]${NC}: "
    read -r php_choice
    php_choice="${php_choice:-2}"

    case "$php_choice" in
        1) PHP_VERSION="8.1" ;;
        3) PHP_VERSION="8.3" ;;
        4) PHP_VERSION="8.4" ;;
        *) PHP_VERSION="8.2" ;;
    esac

    print_header "🗄️ Veritabanı Bilgileri"

    local default_db_name
    default_db_name=$(echo "${APP_NAME}" | tr '-' '_')
    read_required "Veritabanı adı" DB_NAME "$default_db_name"

    local default_db_user="${default_db_name}_user"
    read_required "Veritabanı kullanıcı adı" DB_USER "$default_db_user"

    read_secret "Veritabanı şifresi" DB_PASS

    # Yedekleme dizini
    BACKUP_DIR="/var/backups/laravel-manager"
}

# Özet göster ve onay al
show_summary() {
    print_header "📋 Kurulum Özeti"

    print_table_row "Proje Adı:" "$APP_NAME" "$GREEN"
    print_table_row "Proje Dizini:" "$APP_DIR" "$WHITE"
    print_table_row "Sunucu IP:" "$SERVER_IP" "$WHITE"
    print_table_row "Domain:" "${DOMAIN:-Yapılandırılmadı}" "$WHITE"
    print_separator
    print_table_row "GitHub:" "${GITHUB_USER}/${GITHUB_REPO}" "$WHITE"
    print_table_row "Branch:" "$GITHUB_BRANCH" "$WHITE"
    print_table_row "Repo Tipi:" "$REPO_VISIBILITY" "$WHITE"
    print_table_row "Token:" "$(if [[ -n "$GITHUB_TOKEN" ]]; then echo '********'; else echo 'Yok'; fi)" "$WHITE"
    print_separator
    print_table_row "PHP Sürümü:" "$PHP_VERSION" "$YELLOW"
    print_table_row "DB Adı:" "$DB_NAME" "$WHITE"
    print_table_row "DB Kullanıcı:" "$DB_USER" "$WHITE"
    print_table_row "DB Şifre:" "********" "$WHITE"
    print_separator

    echo ""
    if ! confirm_action "Bu bilgilerle kuruluma başlamak istiyor musunuz?"; then
        print_warning "Kurulum iptal edildi."
        exit 0
    fi
}

# Config dosyasını oluştur
create_config() {
    print_step "Config dosyası oluşturuluyor..."

    cat > "$CONFIG_FILE" << CONF
#!/bin/bash
# ============================================================================
# Laravel Server Manager — Config Dosyası
# ============================================================================
# Bu dosya install.sh tarafından otomatik oluşturulmuştur.
# Elle düzenlemek için: bash scripts/settings.sh
# ============================================================================
# ⚠️  GÜVENLİK: Bu dosya .gitignore'a eklenmiştir. Asla commit etmeyin!
# ============================================================================

# ── Proje Bilgileri ──
APP_NAME="${APP_NAME}"
APP_DIR="${APP_DIR}"
DOMAIN="${DOMAIN}"

# ── Sunucu Bilgileri ──
SERVER_IP="${SERVER_IP}"

# ── GitHub Bilgileri ──
GITHUB_USER="${GITHUB_USER}"
GITHUB_REPO="${GITHUB_REPO}"
GITHUB_BRANCH="${GITHUB_BRANCH}"
REPO_VISIBILITY="${REPO_VISIBILITY}"
GITHUB_TOKEN="${GITHUB_TOKEN}"

# ── Veritabanı Bilgileri ──
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASS="${DB_PASS}"

# ── PHP Bilgileri ──
PHP_VERSION="${PHP_VERSION}"

# ── Yedekleme ──
BACKUP_DIR="${BACKUP_DIR}"
BACKUP_RETENTION_DAYS="30"

# ── Supervisor ──
SUPERVISOR_WORKERS="3"
QUEUE_CONNECTION="database"

# ── Genel ──
DEPLOY_TIMESTAMP=""
LSM_INSTALLED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
CONF

    chmod 600 "$CONFIG_FILE"
    print_success "Config dosyası oluşturuldu: ${CONFIG_FILE}"
}

# Sistem paketlerini güncelle
update_system() {
    print_header "📦 Sistem Güncelleniyor"

    try_run "Paket listesi güncelleniyor" "apt-get update -y"
    try_run "Sistem paketleri güncelleniyor" "DEBIAN_FRONTEND=noninteractive apt-get upgrade -y"
    try_run "Temel araçlar kuruluyor" "apt-get install -y curl wget git unzip software-properties-common apt-transport-https ca-certificates gnupg lsb-release"
}

# PHP kurulumu
install_php() {
    print_header "🐘 PHP ${PHP_VERSION} Kuruluyor"

    # Ondřej Surý PPA ekle
    try_run "PHP PPA ekleniyor" "add-apt-repository -y ppa:ondrej/php"
    try_run "Paket listesi güncelleniyor" "apt-get update -y"

    # PHP ve eklentilerini kur
    local php_packages=(
        "php${PHP_VERSION}"
        "php${PHP_VERSION}-fpm"
        "php${PHP_VERSION}-cli"
        "php${PHP_VERSION}-common"
        "php${PHP_VERSION}-mysql"
        "php${PHP_VERSION}-pgsql"
        "php${PHP_VERSION}-sqlite3"
        "php${PHP_VERSION}-curl"
        "php${PHP_VERSION}-gd"
        "php${PHP_VERSION}-mbstring"
        "php${PHP_VERSION}-xml"
        "php${PHP_VERSION}-zip"
        "php${PHP_VERSION}-bcmath"
        "php${PHP_VERSION}-intl"
        "php${PHP_VERSION}-readline"
        "php${PHP_VERSION}-tokenizer"
        "php${PHP_VERSION}-redis"
        "php${PHP_VERSION}-opcache"
    )

    try_run "PHP ${PHP_VERSION} ve eklentileri kuruluyor" "apt-get install -y ${php_packages[*]}"

    # PHP-FPM'i başlat
    try_run "PHP-FPM başlatılıyor" "systemctl enable php${PHP_VERSION}-fpm && systemctl start php${PHP_VERSION}-fpm"

    print_success "PHP ${PHP_VERSION} başarıyla kuruldu!"
}

# Composer kurulumu
install_composer() {
    print_header "🎼 Composer Kuruluyor"

    if command -v composer &> /dev/null; then
        print_info "Composer zaten kurulu. Güncelleniyor..."
        try_run "Composer güncelleniyor" "composer self-update"
    else
        try_run "Composer indiriliyor" "curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php"
        try_run "Composer kuruluyor" "php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer"
        rm -f /tmp/composer-setup.php
        print_success "Composer başarıyla kuruldu!"
    fi
}

# Node.js ve NPM kurulumu
install_nodejs() {
    print_header "🟢 Node.js ve NPM Kuruluyor"

    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        local node_ver
        node_ver=$(node -v 2>/dev/null || echo "")
        local npm_ver
        npm_ver=$(npm -v 2>/dev/null || echo "")
        print_info "Node.js (${node_ver}) ve NPM (${npm_ver}) zaten kurulu."
        return 0
    fi

    print_step "NodeSource Node.js 20 LTS deposu yapılandırılıyor..."
    if curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1; then
        try_run "Node.js ve NPM kuruluyor (NodeSource LTS)" "apt-get install -y nodejs"
    else
        try_run "Standart Node.js ve NPM kuruluyor" "apt-get install -y nodejs npm"
    fi

    local node_ver
    node_ver=$(node -v 2>/dev/null || echo "Bilinmiyor")
    local npm_ver
    npm_ver=$(npm -v 2>/dev/null || echo "Bilinmiyor")
    print_success "Node.js (${node_ver}) ve NPM (${npm_ver}) başarıyla kuruldu!"
}

# MySQL kurulumu
install_mysql() {
    print_header "🗄️ MySQL Kuruluyor"

    try_run "MySQL Server kuruluyor" "DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server"
    try_run "MySQL başlatılıyor" "systemctl enable mysql && systemctl start mysql"

    # Veritabanı ve kullanıcı oluştur
    print_step "Veritabanı ve kullanıcı oluşturuluyor..."

    mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
    mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';" 2>/dev/null || true
    mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';" 2>/dev/null || true
    mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true

    print_success "Veritabanı '${DB_NAME}' ve kullanıcı '${DB_USER}' oluşturuldu."
}

# Nginx kurulumu
install_nginx() {
    print_header "🌐 Nginx Kuruluyor"

    try_run "Nginx kuruluyor" "apt-get install -y nginx"
    try_run "Nginx başlatılıyor" "systemctl enable nginx && systemctl start nginx"
    print_success "Nginx servisi kuruldu."
}

# Supervisor kurulumu
install_supervisor() {
    print_header "👷 Supervisor Kuruluyor"

    try_run "Supervisor kuruluyor" "apt-get install -y supervisor"
    try_run "Supervisor başlatılıyor" "systemctl enable supervisor && systemctl start supervisor"
    print_success "Supervisor servisi kuruldu."
}

# Laravel Nginx Vhost konfigürasyonu (Proje klonlandıktan sonra çağrılır)
configure_nginx_vhost() {
    print_header "🌐 Nginx Vhost Yapılandırılıyor"
    print_step "Nginx konfigürasyonu oluşturuluyor..."

    local server_name="${DOMAIN:-${SERVER_IP}}"
    local nginx_conf="/etc/nginx/sites-available/${APP_NAME}"

    # Eski veya bozuk fastcgi_param satırlarını onar
    for conf in /etc/nginx/sites-available/*; do
        [[ -f "$conf" ]] || continue
        if grep -q "fastcgi_param[[:space:]]*SCRIPT_FILENAME" "$conf" 2>/dev/null; then
            sed -i 's|fastcgi_param[[:space:]]*SCRIPT_FILENAME.*;|fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;|' "$conf" 2>/dev/null || true
        fi
    done

    cat > "$nginx_conf" << NGINX
server {
    listen 80;
    listen [::]:80;

    server_name ${server_name};
    root ${APP_DIR}/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";

    index index.php index.html index.htm;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php\$ {
        fastcgi_pass unix:/var/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }

    # Güvenlik: .env dosyasına erişimi engelle
    location ~ /\.env {
        deny all;
        return 404;
    }
}
NGINX

    # Site'ı etkinleştir
    ln -sf "$nginx_conf" "/etc/nginx/sites-enabled/${APP_NAME}"

    # Default site'ı devre dışı bırak
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

    # Nginx config testi
    local test_output
    test_output=$(nginx -t 2>&1)
    if echo "$test_output" | grep -q "successful"; then
        try_run "Nginx yeniden başlatılıyor" "systemctl reload nginx"
        print_success "Nginx konfigürasyonu oluşturuldu ve etkinleştirildi."
    else
        print_warning "Nginx konfigürasyonunda hata tespit edildi:"
        echo "$test_output" | while read -r line; do echo "  $line"; done
    fi
}

# Laravel Supervisor Worker konfigürasyonu (Proje klonlandıktan sonra çağrılır)
configure_supervisor_worker() {
    print_header "👷 Supervisor Worker Yapılandırılıyor"
    print_step "Supervisor konfigürasyonu oluşturuluyor..."

    # Logs dizini ve log dosyasını önceden hazırla
    mkdir -p "${APP_DIR}/storage/logs" 2>/dev/null || true
    touch "${APP_DIR}/storage/logs/worker.log" 2>/dev/null || true
    chown -R www-data:www-data "${APP_DIR}/storage" 2>/dev/null || true

    local supervisor_conf="/etc/supervisor/conf.d/${APP_NAME}-worker.conf"

    cat > "$supervisor_conf" << SUPERVISOR
[program:${APP_NAME}-worker]
process_name=%(program_name)s_%(process_num)02d
command=php ${APP_DIR}/artisan queue:work ${QUEUE_CONNECTION:-database} --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
user=www-data
numprocs=${SUPERVISOR_WORKERS:-3}
redirect_stderr=true
stdout_logfile=${APP_DIR}/storage/logs/worker.log
stopwaitsecs=3600
SUPERVISOR

    print_step "Supervisor konfigürasyonu yükleniyor..."
    supervisorctl reread > /dev/null 2>&1 || true
    if supervisorctl update > /dev/null 2>&1; then
        print_success "Supervisor worker'ları başarıyla başlatıldı."
    else
        print_warning "Supervisor worker henüz başlatılamadı (Queue bağlantısı hazır olduğunda otomatik çalışacaktır)."
    fi
}

# Certbot (Let's Encrypt) kurulumu
install_certbot() {
    print_header "🔒 Certbot Kuruluyor"

    try_run "Certbot kuruluyor" "apt-get install -y certbot python3-certbot-nginx"
    print_success "Certbot kuruldu. SSL sertifikası almak için: bash scripts/setup-ssl.sh"
}

# UFW Firewall ayarları
configure_firewall() {
    print_header "🛡️ Güvenlik Duvarı Yapılandırılıyor"

    try_run "UFW kuruluyor" "apt-get install -y ufw"
    try_run "SSH izni veriliyor" "ufw allow OpenSSH"
    try_run "Nginx HTTP/HTTPS izni veriliyor" "ufw allow 'Nginx Full'"
    try_run "MySQL izni veriliyor (sadece localhost)" "ufw allow from 127.0.0.1 to any port 3306"

    # UFW'yi etkinleştir
    echo "y" | ufw enable 2>/dev/null || true
    print_success "Güvenlik duvarı yapılandırıldı."
}

# GitHub'dan projeyi klonla
clone_repository() {
    print_header "📥 Proje Klonlanıyor"

    # Dizini oluştur
    mkdir -p "$(dirname "$APP_DIR")"

    # Repo URL oluştur
    local repo_url
    if [[ "$REPO_VISIBILITY" == "private" && -n "$GITHUB_TOKEN" ]]; then
        repo_url="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
        print_info "Private repo klonlanıyor (token ile)..."
    else
        repo_url="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
        print_info "Public repo klonlanıyor..."
    fi

    # Eğer dizin zaten varsa
    if [[ -d "$APP_DIR" ]]; then
        if [[ -d "${APP_DIR}/.git" ]]; then
            print_warning "Proje dizini zaten mevcut. Güncelleniyor..."
            cd "$APP_DIR"
            git pull origin "$GITHUB_BRANCH" 2>/dev/null || true
            cd - > /dev/null
        else
            print_warning "Dizin mevcut ama Git repo değil. Temizlenip yeniden klonlanıyor..."
            rm -rf "$APP_DIR"
            git clone -b "$GITHUB_BRANCH" "$repo_url" "$APP_DIR"
        fi
    else
        try_run_verbose "Repo klonlanıyor" "git clone -b ${GITHUB_BRANCH} ${repo_url} ${APP_DIR}"
    fi

    print_success "Proje başarıyla klonlandı: ${APP_DIR}"
}

# Laravel'i yapılandır
configure_laravel() {
    print_header "⚙️ Laravel Yapılandırılıyor"

    cd "$APP_DIR"

    # .env dosyası oluştur
    if [[ -f ".env.example" ]]; then
        cp .env.example .env
        print_success ".env dosyası oluşturuldu."
    else
        print_warning ".env.example bulunamadı. Boş .env oluşturuluyor..."
        touch .env
    fi

    # .env değerlerini güncelle
    print_step ".env yapılandırılıyor..."

    # sed ile .env düzenleme
    sed -i "s|^APP_NAME=.*|APP_NAME=\"${APP_NAME}\"|" .env 2>/dev/null || true
    sed -i "s|^APP_URL=.*|APP_URL=http://${DOMAIN:-${SERVER_IP}}|" .env 2>/dev/null || true
    sed -i "s|^APP_ENV=.*|APP_ENV=production|" .env 2>/dev/null || true
    sed -i "s|^APP_DEBUG=.*|APP_DEBUG=false|" .env 2>/dev/null || true

    sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env 2>/dev/null || true
    sed -i "s|^DB_PORT=.*|DB_PORT=3306|" .env 2>/dev/null || true
    sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env 2>/dev/null || true
    sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env 2>/dev/null || true
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env 2>/dev/null || true

    sed -i "s|^QUEUE_CONNECTION=.*|QUEUE_CONNECTION=${QUEUE_CONNECTION:-database}|" .env 2>/dev/null || true

    print_success ".env yapılandırıldı."

    # Composer install
    try_run_verbose "Composer bağımlılıkları kuruluyor" "composer install --no-dev --optimize-autoloader --no-interaction 2>&1"

    # Application key
    try_run "Application key oluşturuluyor" "php artisan key:generate --force"

    # Migration
    try_run_verbose "Veritabanı migrate ediliyor" "php artisan migrate --force 2>&1"

    # Storage link
    try_run "Storage symlink oluşturuluyor" "php artisan storage:link"

    # Front-end assets (Vite / Mix)
    if [[ -f "package.json" ]]; then
        print_step "Front-end paketleri kontrol ediliyor..."
        if ! command -v npm &> /dev/null; then
            try_run "Node.js ve NPM kuruluyor" "apt-get install -y nodejs npm"
        fi
        if command -v npm &> /dev/null; then
            try_run_verbose "NPM bağımlılıkları kuruluyor" "npm install --no-audit 2>&1"
            try_run_verbose "Asset'ler derleniyor (npm run build)" "npm run build 2>&1"
        fi
    fi

    # Cache oluştur
    try_run "Config cache oluşturuluyor" "php artisan config:cache"
    try_run "Route cache oluşturuluyor" "php artisan route:cache"
    try_run "View cache oluşturuluyor" "php artisan view:cache"

    # Dosya izinleri
    print_step "Dosya izinleri ayarlanıyor..."
    chown -R www-data:www-data "$APP_DIR"
    find "$APP_DIR" -type f -exec chmod 644 {} \;
    find "$APP_DIR" -type d -exec chmod 755 {} \;
    chmod -R 775 "$APP_DIR/storage" "$APP_DIR/bootstrap/cache"
    chmod 640 "$APP_DIR/.env"

    print_success "Laravel yapılandırması tamamlandı!"

    cd - > /dev/null
}

# Kurulum sonuç raporu
show_final_report() {
    clear
    echo ""
    echo -e "${GREEN}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo -e "  ║   ${BOLD}${WHITE}✅ KURULUM BAŞARIYLA TAMAMLANDI!${NC}${GREEN}                     ║"
    echo "  ║                                                          ║"
    echo -e "  ╠══════════════════════════════════════════════════════════╣${NC}"
    echo ""

    print_table_row "Proje Adı:" "$APP_NAME" "$GREEN"
    print_table_row "Proje Dizini:" "$APP_DIR" "$WHITE"
    print_table_row "Sunucu IP:" "$SERVER_IP" "$WHITE"
    print_table_row "Domain:" "${DOMAIN:-Yapılandırılmadı}" "$WHITE"
    print_table_row "PHP Sürümü:" "$PHP_VERSION" "$YELLOW"
    print_table_row "Veritabanı:" "$DB_NAME" "$WHITE"

    echo ""
    print_separator
    echo ""

    echo -e "  ${BOLD}${CYAN}🔗 Erişim Bilgileri:${NC}"
    if [[ -n "$DOMAIN" ]]; then
        print_table_row "Web:" "http://${DOMAIN}" "$GREEN"
    fi
    print_table_row "IP:" "http://${SERVER_IP}" "$GREEN"
    echo ""

    echo -e "  ${BOLD}${CYAN}📌 Sonraki Adımlar:${NC}"
    echo -e "  ${WHITE}  1. Ana menüye erişim    :${NC} ${YELLOW}bash ${SCRIPT_DIR}/main.sh${NC}"
    echo -e "  ${WHITE}  2. Deploy/Güncelleme    :${NC} ${YELLOW}bash ${SCRIPT_DIR}/deploy.sh${NC}"
    echo -e "  ${WHITE}  3. SSL Kurulumu         :${NC} ${YELLOW}bash ${SCRIPT_DIR}/setup-ssl.sh${NC}"
    echo -e "  ${WHITE}  4. Sistem Durumu        :${NC} ${YELLOW}bash ${SCRIPT_DIR}/status.sh${NC}"
    echo ""

    if [[ -n "$DOMAIN" ]]; then
        echo -e "  ${BOLD}${YELLOW}💡 İpucu:${NC} SSL sertifikası almak için: ${WHITE}bash ${SCRIPT_DIR}/setup-ssl.sh${NC}"
    fi

    echo ""
    echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# ANA AKIŞ
# ============================================================================

main() {
    local start_time
    start_time=$(date +%s)

    show_welcome
    check_root

    echo ""
    if ! confirm_action "Kuruluma başlamak istiyor musunuz?"; then
        print_warning "Kurulum iptal edildi."
        exit 0
    fi

    # Bilgi toplama
    collect_information

    # Özet göster
    show_summary

    echo ""
    print_header "🔧 Kurulum Başlıyor"

    # Config oluştur
    create_config

    # Sistem güncellemesi
    update_system

    # Paket kurulumları
    install_php
    install_composer
    install_nodejs
    install_mysql
    install_nginx
    install_supervisor
    install_certbot
    configure_firewall

    # Proje kurulumu (Önce repo klonlanır ve Laravel yapılandırılır)
    clone_repository
    configure_laravel

    # Proje hazır olduktan sonra Nginx Vhost ve Supervisor Worker yapılandırılır
    configure_nginx_vhost
    configure_supervisor_worker

    # Logs dizinini oluştur
    mkdir -p "${SCRIPT_DIR}/../logs"

    # Log kaydet
    log_action "İlk kurulum tamamlandı. Proje: ${APP_NAME}, PHP: ${PHP_VERSION}" "SUCCESS"

    # Sonuç raporu
    show_final_report

    local elapsed
    elapsed=$(elapsed_time "$start_time")
    echo -e "  ${GRAY}Toplam kurulum süresi: ${elapsed}${NC}"
    echo ""
}

# Script'i çalıştır
main "$@"
