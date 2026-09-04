# 🚀 Laravel Server Manager & DevOps Toolkit

<div align="center">

[![Bash](https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Laravel](https://img.shields.io/badge/Laravel-Ready-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)](https://laravel.com)
[![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Ubuntu%2020.04+-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)

**Herhangi bir Laravel projesinde tak-çalıştır şeklinde kullanılabilen, modüler sunucu yönetim ve otomasyon aracı.**

[Hızlı Başlangıç](#-hızlı-başlangıç) · [Özellikler](#-özellikler) · [Komutlar](#-komutlar) · [Katkıda Bulunma](#-katkıda-bulunma)

</div>

---

## ✨ Özellikler

- 🔧 **Config-Driven Mimari** — Hiçbir IP, şifre veya proje adı hardcode edilmez
- 🚀 **Tek Komutla Kurulum** — İnteraktif sihirbaz ile sunucu sıfırdan yapılandırılır
- 📊 **Kapsamlı Durum Raporu** — Sistem, servisler ve Laravel sağlık kontrolü
- 🔄 **Akıllı Deploy** — Maintenance mode, git pull, migrate, cache, izin düzeltme
- 🗄️ **Veritabanı Yönetimi** — Yedekleme, geri yükleme, otomatik temizlik
- 🔒 **SSL Kurulumu** — Let's Encrypt sertifikası, otomatik yenileme
- 🛡️ **Güvenlik Araçları** — IP engelleme, güvenlik taraması, firewall yönetimi
- 👷 **Queue Worker Yönetimi** — Supervisor entegrasyonu, worker ölçekleme
- 🧹 **Bakım Araçları** — Cache, izin, storage, disk, session yönetimi
- 🌐 **Servis Yönetimi** — Nginx, MySQL, PHP-FPM, Supervisor, Redis

## 📋 Gereksinimler

- **İşletim Sistemi:** Ubuntu 20.04 veya üzeri (Debian tabanlı)
- **Erişim:** Root (sudo) yetkisi
- **Ağ:** İnternet bağlantısı (paket kurulumu ve GitHub erişimi için)

## 🚀 Hızlı Başlangıç

### 1. Projeyi Klonlayın

```bash
git clone https://github.com/kullanici/laravel-server-manager.git
cd laravel-server-manager
```

### 2. İlk Kurulumu Başlatın

```bash
sudo bash scripts/install.sh
```

Kurulum sihirbazı size şu soruları soracak:
- 📝 Proje adı ve dizin yolu
- 🌐 Sunucu IP adresi ve domain
- 🔗 GitHub repo bilgileri (Public/Private)
- 🐘 PHP sürümü (8.1 / 8.2 / 8.3)
- 🗄️ Veritabanı bilgileri

### 3. Ana Menüye Girin

```bash
bash scripts/main.sh
# veya kısa yol:
bash scripts/mm.sh
```

## 🖥️ Ana Menü

```
╔══════════════════════════════════════════════════════════╗
║  🚀 Laravel Server Manager              v1.0.0         ║
╠══════════════════════════════════════════════════════════╣
║  Aktif Proje: my-laravel-app                            ║
║  Sunucu IP  : 192.168.1.100                             ║
╚══════════════════════════════════════════════════════════╝

   0)  📊  Sistem Durumu
   1)  🚀  Deploy / Güncelleme
   2)  ⚙️   Ayarları Yönet / Değiştir
   3)  🔄  Servisleri Yeniden Başlat
   4)  📁  Dosya İzinlerini Düzelt
   5)  🧹  Laravel Cache Temizle / Yenile
   6)  🔗  Storage Symlink Onar
   7)  👷  Queue Worker Yönetimi
   8)  ❌  Başarısız Job'ları Yönet
   9)  💾  Disk Alanını Temizle
  10)  📦  Veritabanı Yedeği Al
  11)  📥  Yedekten Geri Yükle
  12)  🔒  SSL Kurulumu (Let's Encrypt)
  13)  🛡️   IP Engelle / Güvenlik Duvarı
  14)  🔐  Güvenlik Taraması
  15)  🔌  MySQL Bağlantı Yönetimi
  16)  🌐  Nginx Yönetimi
  17)  🕐  Session Yönetimi
   q)  🚪  Çıkış
```

## 📁 Dosya Yapısı

```
laravel-server-manager/
├── scripts/
│   ├── common.sh               # Ortak kütüphane (renkler, hata yönetimi, fonksiyonlar)
│   ├── config.sh               # Merkezi ayar dosyası (otomatik oluşturulur)
│   ├── config.sh.example       # Örnek config dosyası
│   ├── install.sh              # İlk kurulum sihirbazı
│   ├── main.sh                 # Ana interaktif yönetim paneli
│   ├── mm.sh                   # main.sh kısayolu
│   ├── settings.sh             # Ayar yönetim ekranı
│   ├── deploy.sh               # Akıllı deploy / güncelleme
│   ├── status.sh               # Sistem durumu raporu
│   ├── backup-db.sh            # Veritabanı yedekleme
│   ├── restore-db.sh           # Yedekten geri yükleme
│   ├── setup-ssl.sh            # Let's Encrypt SSL kurulumu
│   ├── block-ip.sh             # IP engelleme / güvenlik duvarı
│   ├── fix-permissions.sh      # Dosya izinleri düzeltme
│   ├── fix-laravel-cache.sh    # Laravel cache yönetimi
│   ├── fix-storage.sh          # Storage symlink onarımı
│   ├── fix-queue.sh            # Queue worker yönetimi
│   ├── fix-failed-jobs.sh      # Başarısız job yönetimi
│   ├── fix-disk.sh             # Disk alanı temizleme
│   ├── fix-services.sh         # Servis yönetimi
│   ├── fix-mysql-connections.sh # MySQL bağlantı yönetimi
│   ├── fix-nginx-version.sh    # Nginx yönetimi
│   ├── fix-security.sh         # Güvenlik taraması
│   └── fix-sessions.sh         # Session yönetimi
├── .gitignore
├── LICENSE
├── CLAUDE.md
└── README.md
```

## 📖 Komutlar

### Kurulum & Yapılandırma

| Komut | Açıklama |
|-------|----------|
| `sudo bash scripts/install.sh` | İlk kurulum sihirbazı |
| `bash scripts/settings.sh` | Ayarları görüntüle/değiştir |
| `bash scripts/main.sh` | Ana yönetim menüsü |

### Deploy & Bakım

| Komut | Açıklama |
|-------|----------|
| `bash scripts/deploy.sh` | Akıllı deploy (git pull + migrate + cache) |
| `bash scripts/status.sh` | Sistem durumu raporu |
| `bash scripts/fix-laravel-cache.sh` | Cache temizle/yenile |
| `sudo bash scripts/fix-permissions.sh` | Dosya izinlerini düzelt |
| `bash scripts/fix-storage.sh` | Storage symlink onar |

### Veritabanı

| Komut | Açıklama |
|-------|----------|
| `bash scripts/backup-db.sh` | Veritabanı yedeği al |
| `bash scripts/restore-db.sh` | Yedekten geri yükle |
| `sudo bash scripts/fix-mysql-connections.sh` | MySQL bağlantıları yönet |

### Güvenlik

| Komut | Açıklama |
|-------|----------|
| `sudo bash scripts/setup-ssl.sh` | SSL sertifikası al/yenile |
| `sudo bash scripts/block-ip.sh` | IP engelle/kaldır |
| `sudo bash scripts/fix-security.sh` | Güvenlik taraması |

### Servisler & Queue

| Komut | Açıklama |
|-------|----------|
| `sudo bash scripts/fix-services.sh` | Servisleri yönet |
| `bash scripts/fix-queue.sh` | Queue worker yönetimi |
| `bash scripts/fix-failed-jobs.sh` | Başarısız job'ları yönet |

## 🔒 Güvenlik

- `config.sh` dosyası `.gitignore`'a eklenmiştir ve **asla** Git'e commit edilmemelidir
- Config dosyası `600` izinleriyle oluşturulur (sadece sahibi okuyabilir)
- GitHub PAT ve veritabanı şifreleri sadece `config.sh` içinde tutulur
- `.env` dosyasına web erişimi Nginx konfigürasyonunda engellenmiştir

## 🤝 Katkıda Bulunma

1. Bu repo'yu fork edin
2. Feature branch oluşturun (`git checkout -b feature/yeni-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -m 'Yeni özellik eklendi'`)
4. Branch'i push edin (`git push origin feature/yeni-ozellik`)
5. Pull Request açın

## 📄 Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır.

---

<div align="center">

**Laravel Server Manager** ile sunucu yönetimi artık çok kolay! 🚀

</div>
