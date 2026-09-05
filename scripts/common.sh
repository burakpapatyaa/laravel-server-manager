#!/bin/bash
# ============================================================================
# Laravel Server Manager — Ortak Kütüphane (common.sh)
# ============================================================================
# Tüm scriptler tarafından source edilen merkezi fonksiyon kütüphanesi.
# Renkli çıktı, hata yönetimi, input validation, config yükleme vb.
# ============================================================================

# Strict mode
set -euo pipefail

# ============================================================================
# RENK TANIMLARI
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly UNDERLINE='\033[4m'
readonly BLINK='\033[5m'
readonly NC='\033[0m' # No Color (Reset)

# Arka plan renkleri
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'
readonly BG_MAGENTA='\033[45m'
readonly BG_CYAN='\033[46m'

# ============================================================================
# SCRIPT DIZIN YOLU
# ============================================================================
# Bu dosyanın bulunduğu dizin (tüm scriptlerin ortak dizini)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Config dizini ve aktif proje dosyası
CONFIGS_DIR="${SCRIPT_DIR}/configs"
ACTIVE_PROJECT_FILE="${SCRIPT_DIR}/.active_project"

# Geriye dönük uyumluluk: configs/ yoksa eski config.sh'ı kullan
if [[ -f "${SCRIPT_DIR}/config.sh" && ! -d "$CONFIGS_DIR" ]]; then
    CONFIG_FILE="${SCRIPT_DIR}/config.sh"
else
    # Aktif proje adını oku
    _active_proj=""
    if [[ -f "$ACTIVE_PROJECT_FILE" ]]; then
        _active_proj="$(cat "$ACTIVE_PROJECT_FILE" | tr -d '[:space:]')"
    fi
    if [[ -n "$_active_proj" && -f "${CONFIGS_DIR}/${_active_proj}.sh" ]]; then
        CONFIG_FILE="${CONFIGS_DIR}/${_active_proj}.sh"
    else
        CONFIG_FILE="${SCRIPT_DIR}/config.sh"
    fi
fi

# Versiyon
readonly LSM_VERSION="1.0.0"

# ============================================================================
# ÇIKTI FONKSİYONLARI
# ============================================================================

print_success() {
    echo -e "${GREEN}  [✓] $1${NC}"
}

print_error() {
    echo -e "${RED}  [✗] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  [!] $1${NC}"
}

print_info() {
    echo -e "${CYAN}  [i] $1${NC}"
}

print_step() {
    echo -e "${BLUE}  [➤] $1${NC}"
}

print_debug() {
    if [[ "${LSM_DEBUG:-false}" == "true" ]]; then
        echo -e "${GRAY}  [DEBUG] $1${NC}"
    fi
}

# Başlık satırı
print_header() {
    local title="$1"
    local width=56
    local padding=$(( (width - ${#title} - 2) / 2 ))
    local pad_left=$(printf '%*s' "$padding" '' | tr ' ' ' ')
    local pad_right=$(printf '%*s' $(( width - ${#title} - 2 - padding )) '' | tr ' ' ' ')

    echo ""
    echo -e "${CYAN}╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
    echo -e "${CYAN}║${pad_left} ${BOLD}${WHITE}${title}${NC}${CYAN} ${pad_right}║${NC}"
    echo -e "${CYAN}╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
    echo ""
}

# Alt başlık
print_subheader() {
    local title="$1"
    echo ""
    echo -e "${MAGENTA}  ── ${BOLD}${title}${NC}${MAGENTA} ──${NC}"
    echo ""
}

# Ayırıcı çizgi
print_separator() {
    echo -e "${GRAY}  $(printf '─%.0s' $(seq 1 50))${NC}"
}

# Boş satır
print_blank() {
    echo ""
}

# Renkli tablo satırı
print_table_row() {
    local label="$1"
    local value="$2"
    local color="${3:-$WHITE}"
    printf "  ${GRAY}%-25s${NC} ${color}%s${NC}\n" "$label" "$value"
}

# ============================================================================
# BANNER & AKTİF PROJE
# ============================================================================

# Ana banner — her script başında çağrılır
print_banner() {
    local active_project="${APP_NAME:-Yapılandırılmadı}"
    local server_ip="${SERVER_IP:-Bilinmiyor}"
    local width=58

    echo -e "${CYAN}  ╔$(printf '═%.0s' $(seq 1 $width))╗${NC}"
    echo -e "${CYAN}  ║  ${BOLD}${WHITE}$(printf '%-30s' "Laravel Server Manager")${NC}${CYAN} ${DIM}$(printf '%23s' "v${LSM_VERSION}")${NC}${CYAN}  ║${NC}"
    echo -e "${CYAN}  ╠$(printf '═%.0s' $(seq 1 $width))╣${NC}"
    echo -e "${CYAN}  ║  ${GREEN}Aktif Proje:${NC} ${BOLD}${YELLOW}$(printf '%-41s' "${active_project:0:41}")${NC}${CYAN}  ║${NC}"
    echo -e "${CYAN}  ║  ${GREEN}Sunucu IP  :${NC} ${WHITE}$(printf '%-41s' "${server_ip:0:41}")${NC}${CYAN}  ║${NC}"
    echo -e "${CYAN}  ╚$(printf '═%.0s' $(seq 1 $width))╝${NC}"
    echo ""
}

# ============================================================================
# HATA YÖNETİMİ
# ============================================================================

# Global error handler
on_error() {
    local exit_code=$?
    local line_no=$1
    print_error "Hata oluştu! (Satır: ${line_no}, Çıkış Kodu: ${exit_code})"
    print_info "Sorun devam ederse lütfen log dosyalarını kontrol edin."
    exit "$exit_code"
}

# Error trap'i aktifleştir
enable_error_trap() {
    trap 'on_error ${LINENO}' ERR
}

# Komut çalıştırma wrapper'ı (try-catch mantığı)
try_run() {
    local description="$1"
    shift
    local cmd="$*"

    print_step "${description}..."

    if eval "$cmd" > /dev/null 2>&1; then
        print_success "${description} — Başarılı"
        return 0
    else
        local exit_code=$?
        print_error "${description} — Başarısız (Çıkış Kodu: ${exit_code})"
        return "$exit_code"
    fi
}

# Komut çalıştırma (çıktıyı göster)
try_run_verbose() {
    local description="$1"
    shift
    local cmd="$*"

    print_step "${description}..."

    if eval "$cmd"; then
        print_success "${description} — Başarılı"
        return 0
    else
        local exit_code=$?
        print_error "${description} — Başarısız (Çıkış Kodu: ${exit_code})"
        return "$exit_code"
    fi
}

# ============================================================================
# INPUT VALIDATION
# ============================================================================

# Boş olmayan giriş iste
read_required() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"
    local result=""

    while true; do
        if [[ -n "$default" ]]; then
            echo -ne "  ${CYAN}${prompt}${NC} ${GRAY}[${default}]${NC}: "
        else
            echo -ne "  ${CYAN}${prompt}${NC}: "
        fi
        read -r result

        # Varsayılan değer kullan
        if [[ -z "$result" && -n "$default" ]]; then
            result="$default"
        fi

        if [[ -n "$result" ]]; then
            eval "$var_name='$result'"
            return 0
        else
            print_warning "Bu alan boş bırakılamaz. Lütfen tekrar deneyin."
        fi
    done
}

# Opsiyonel giriş
read_optional() {
    local prompt="$1"
    local var_name="$2"
    local default="${3:-}"
    local result=""

    if [[ -n "$default" ]]; then
        echo -ne "  ${CYAN}${prompt}${NC} ${GRAY}[${default}]${NC}: "
    else
        echo -ne "  ${CYAN}${prompt}${NC} ${GRAY}[Boş bırakılabilir]${NC}: "
    fi
    read -r result

    if [[ -z "$result" ]]; then
        result="$default"
    fi

    eval "$var_name='$result'"
}

# Gizli giriş (şifre vb.)
read_secret() {
    local prompt="$1"
    local var_name="$2"
    local result=""

    while true; do
        echo -ne "  ${CYAN}${prompt}${NC}: "
        read -rs result
        echo ""

        if [[ -n "$result" ]]; then
            eval "$var_name='$result'"
            return 0
        else
            print_warning "Bu alan boş bırakılamaz. Lütfen tekrar deneyin."
        fi
    done
}

# Evet/Hayır onayı
confirm_action() {
    local prompt="$1"
    local default="${2:-e}"  # varsayılan: evet
    local yn_hint

    if [[ "$default" == "e" ]]; then
        yn_hint="E/h"
    else
        yn_hint="e/H"
    fi

    echo -ne "  ${YELLOW}${prompt}${NC} ${GRAY}[${yn_hint}]${NC}: "
    read -r response
    response="${response:-$default}"

    case "$response" in
        [eEyY]|[eE][vV][eE][tT])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Menüden seçim yap
read_menu_choice() {
    local prompt="${1:-Seçiminiz}"
    local result=""

    echo -ne "\n  ${BOLD}${CYAN}${prompt}${NC}${CYAN} ➤ ${NC}" >&2
    if ! read -r result; then
        echo "q"
        return 0
    fi
    # Boşlukları ve carriage return'ü temizle
    result="${result#"${result%%[![:space:]]*}"}"
    result="${result%"${result##*[![:space:]]}"}"
    result="${result//$'\r'/}"
    echo "$result"
}

# ============================================================================
# YETKİ KONTROLLERİ
# ============================================================================

# Root yetkisi gerektir
require_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Bu script root yetkisi gerektirir!"
        print_info "Şu komutla çalıştırın: sudo bash $0"
        exit 1
    fi
}

# Root olmamasını gerektir (opsiyonel güvenlik)
require_non_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Bu script root olmayan bir kullanıcı ile çalıştırılmalıdır."
        if ! confirm_action "Root olarak devam etmek istiyor musunuz?"; then
            exit 0
        fi
    fi
}

# ============================================================================
# CONFIG YÖNETİMİ
# ============================================================================

# Config dosyasını yükle
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Config dosyası bulunamadı: ${CONFIG_FILE}"
        print_info "İlk kurulum için: sudo bash ${SCRIPT_DIR}/install.sh"
        exit 1
    fi

    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    print_debug "Config yüklendi: ${CONFIG_FILE}"

    # Git safe.directory kontrolü (dubious ownership hatasını önler)
    if command -v git &>/dev/null && [[ -n "${APP_DIR:-}" && -d "${APP_DIR:-}" ]]; then
        if ! git config --global --get-all safe.directory 2>/dev/null | grep -Fxq "$APP_DIR"; then
            git config --global --add safe.directory "$APP_DIR" 2>/dev/null || true
        fi
    fi
}

# Config dosyasının varlığını kontrol et
check_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        return 1
    fi
    return 0
}

# Config değerini güncelle
update_config_value() {
    local key="$1"
    local value="$2"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Config dosyası bulunamadı!"
        return 1
    fi

    # Mevcut değeri güncelle veya yeni ekle
    if grep -q "^${key}=" "$CONFIG_FILE"; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$CONFIG_FILE"
    else
        echo "${key}=\"${value}\"" >> "$CONFIG_FILE"
    fi

    print_debug "Config güncellendi: ${key}=${value}"
}

# Config'i dışa aktar
export_config() {
    local export_file="$1"
    local mask_secrets="${2:-true}"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "Config dosyası bulunamadı!"
        return 1
    fi

    if [[ "$mask_secrets" == "true" ]]; then
        # Hassas bilgileri maskele
        sed -e 's/\(DB_PASS=\)".*"/\1"********"/' \
            -e 's/\(GITHUB_TOKEN=\)".*"/\1"********"/' \
            "$CONFIG_FILE" > "$export_file"
        print_success "Config dışa aktarıldı (hassas bilgiler maskelendi): ${export_file}"
    else
        cp "$CONFIG_FILE" "$export_file"
        print_success "Config dışa aktarıldı: ${export_file}"
    fi
}

# Config'i içe aktar
import_config() {
    local import_file="$1"

    if [[ ! -f "$import_file" ]]; then
        print_error "İçe aktarılacak dosya bulunamadı: ${import_file}"
        return 1
    fi

    # Mevcut config'i yedekle
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
        print_info "Mevcut config yedeklendi."
    fi

    cp "$import_file" "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    print_success "Config içe aktarıldı: ${import_file}"
}

# ============================================================================
# SERVİS YÖNETİMİ
# ============================================================================

# Servis durumunu kontrol et
check_service_status() {
    local service="$1"

    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${GREEN}● Çalışıyor${NC}"
        return 0
    elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo -e "${YELLOW}○ Durdurulmuş${NC}"
        return 0
    else
        echo -e "${RED}✗ Kurulu Değil${NC}"
        return 0
    fi
}

# Servisi yeniden başlat
restart_service() {
    local service="$1"
    try_run "${service} yeniden başlatılıyor" "systemctl restart ${service}"
}

# ============================================================================
# YARDIMCI FONKSİYONLAR
# ============================================================================

# PHP artisan komutunu çalıştır
run_artisan() {
    local app_dir="${APP_DIR:-.}"
    local cmd="$1"
    shift
    php "${app_dir}/artisan" "$cmd" "$@"
}

# Dosya boyutunu okunabilir formata çevir
human_readable_size() {
    local size=$1
    if (( size >= 1073741824 )); then
        printf "%.1f GB" "$(echo "scale=1; $size/1073741824" | bc)"
    elif (( size >= 1048576 )); then
        printf "%.1f MB" "$(echo "scale=1; $size/1048576" | bc)"
    elif (( size >= 1024 )); then
        printf "%.1f KB" "$(echo "scale=1; $size/1024" | bc)"
    else
        printf "%d B" "$size"
    fi
}

# Tarih/saat formatla
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Tarih (dosya adı için)
datestamp() {
    date "+%Y%m%d_%H%M%S"
}

# Script'in çalışma süresini hesapla
elapsed_time() {
    local start=$1
    local end
    end=$(date +%s)
    local diff=$(( end - start ))
    local mins=$(( diff / 60 ))
    local secs=$(( diff % 60 ))

    if (( mins > 0 )); then
        echo "${mins} dakika ${secs} saniye"
    else
        echo "${secs} saniye"
    fi
}

# Devam etmek için bekle
press_enter_to_continue() {
    echo ""
    echo -ne "  ${GRAY}Devam etmek için Enter'a basın...${NC}"
    read -r
}

# Spinner (uzun işlemler için)
show_spinner() {
    local pid=$1
    local message="${2:-İşleniyor}"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        local c="${spin:i++%${#spin}:1}"
        echo -ne "\r  ${CYAN}${c}${NC} ${message}..."
        sleep 0.1
    done
    echo -ne "\r"
}

# ============================================================================
# LOG YÖNETİMİ
# ============================================================================

# Log dosyasına yaz
log_action() {
    local log_file="${SCRIPT_DIR}/../logs/lsm.log"
    local message="$1"
    local level="${2:-INFO}"

    # Log dizinini oluştur
    mkdir -p "$(dirname "$log_file")"

    echo "[$(timestamp)] [${level}] ${message}" >> "$log_file"
}

# ============================================================================
# DOĞRULAMA FONKSİYONLARI
# ============================================================================

# IP adresi doğrulama
validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

# Domain adı doğrulama
validate_domain() {
    local domain="$1"
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# Dizin yolu doğrulama
validate_path() {
    local path="$1"
    if [[ "$path" =~ ^/ ]]; then
        return 0
    fi
    return 1
}

# ============================================================================
# TAMAMLAMA MESAJI
# ============================================================================

print_completion() {
    local script_name="$1"
    local start_time="$2"

    print_separator
    print_success "${script_name} tamamlandı! (${BOLD}$(elapsed_time "$start_time")${NC}${GREEN})"
    print_separator
    echo ""
}
