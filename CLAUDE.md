Sen kıdemli bir DevOps mühendisi ve otomasyon uzmanısın. GitHub üzerinde public olarak yayınlanacak, her türlü Laravel projesinde (Public veya Private repolar, farklı PHP sürümleri, Supervisor, Nginx, MySQL vb.) tak-çalıştır şeklinde kullanılabilen modüler bir "Laravel Server Manager & DevOps Toolkit" projesi inşa edeceğiz.

Proje mimarisi tamamen "Config-Driven" (Ayar Dosyasına Dayalı) olacak. Sabit hiçbir proje adı, IP adresi veya şifre kodların içinde hardcode olmayacak.

Lütfen bana bu proje için aşağıdaki dosya yapısını ve her bir dosyanın içeriğini eksiksiz, profesyonel ve bash script standartlarına uygun olarak yaz:

1. `scripts/config.sh` (Merkezi Ayar Dosyası):
   - Sistemdeki tüm değişkenlerin (App Name, App Dir, Server IP, GitHub Repo URL, GitHub Token, DB adı, kullanıcı adı, şifre vb.) tutulduğu dosya.
   - İlk kurulumda `install.sh` tarafından otomatik oluşturulacak.

2. `scripts/install.sh` (İlk Kurulum Sihirbazı - Root Yetkisi İster):
   - Kullanıcıya interaktif sorular soracak: Proje adı nedir? Proje dizin yolu neresidir? Sunucu IP adresi nedir? GitHub kullanıcı adı ve repo adı nedir? Repo Public mi Private mi? Private ise GitHub Personal Access Token (PAT) nedir? Veritabanı adı, kullanıcı adı ve şifresi ne olsun?
   - Alınan bu yanıtları dinamik olarak `scripts/config.sh` dosyasına kaydedecek.
   - Sistem paketlerini güncelleyecek, PHP 8.2 (veya istenen sürüm), Composer, MySQL, Nginx ve Supervisor kurulumlarını yapacak.
   - GitHub'dan repoyu (Public/Private desteğiyle) belirrtilen klasöre klonlayacak.
   - .env dosyasını otomatik ayarlayıp, composer install, key:generate, migrate, storage:link ve Nginx/Supervisor konfigürasyonlarını kusursuzca tamamlayacak.

3. `scripts/main.sh` (Ana İnteraktif Yönetim Paneli):
   - Renkli, şık ve numaralandırılmış bir konsol menüsü olacak.
   - Seçenekler şunları içermeli:
     0) Sistem Durumu (status.sh)
     1) Deploy / Güncelleme (deploy.sh)
     2) Ayarları Yönet / Değiştir (settings.sh)
     3) MySQL/Nginx/PHP Servislerini Yeniden Başlat / Kurtar
     4) Dosya İzinlerini Düzelt (fix-permissions.sh)
     5) Laravel Cache Temizle / Yenile (fix-laravel-cache.sh)
     6) Storage Symlink Onar (fix-storage.sh)
     7) Queue Worker Yönetimi (fix-queue.sh)
     8) Başarısız Job'ları Yönet (fix-failed-jobs.sh)
     9) Disk Alanını Temizle
    10) Veritabanı Yedeği Al (backup-db.sh)
    11) Yedekten Geri Yükle (restore-db.sh)
    12) Let's Encrypt SSL Kurulumu (setup-ssl.sh)
    13) IP Engelle / Güvenlik Duvarı (block-ip.sh)
     q) Çıkış

4. `scripts/settings.sh` (Ayar Yönetim Ekranı):
   - Mevcut `config.sh` içindeki değerleri ekrana yazdıracak.
   - Kullanıcıya "Hangi ayarı değiştirmek istiyorsun?" diye soracak (Örn: Token'ı değiştir, DB şifresini değiştir, IP güncelle vb.) ve güvenli bir şekilde `config.sh` dosyasını güncelleyecek.

5. `scripts/deploy.sh` (Akıllı Güncelleme / Deploy Betiği):
   - `config.sh` dosyasındaki bilgileri okuyacak.
   - Private/Public repo durumuna göre GitHub'dan en güncel kodları çekecek (`git pull`).
   - `composer install`, `php artisan migrate --force`, cache temizliği ve dosya izinlerini (`www-data`) otomatik yapacak.

6. Diğer Modüler Yardımcı Betikler (`status.sh`, `fix-permissions.sh`, `fix-laravel-cache.sh`, `backup-db.sh`, `restore-db.sh`, `setup-ssl.sh`, `block-ip.sh` vb.):
   - Her biri tek bir sorumluluğa sahip (`Single Responsibility`), `config.sh` dosyasını `source` ederek ortak değişkenleri kullanan güvenli bash betikleri olacak.

7. `README.md` (Kusursuz GitHub Dokümantasyonu):
   - Bu projenin ne işe yaradığını, nasıl klonlanacağını, ilk kurulumun nasıl başlatılacağını (`sudo bash scripts/install.sh`), ana menüye nasıl girileceğini (`./scripts/main.sh`) adım adım, ekran örnekleriyle anlatan çok profesyonel bir README dosyası.

Kodları yazarken hata yönetimini (`set -e` ve try-catch mantığı), renkli terminal çıktılarını (`echo -e`) ve güvenlik önlemlerini üst düzeyde tut. Hazırsan tüm dosyaları eksiksiz olarak üret.





Burada yazanlara ek olarak bu mesajımda ki görsele de bak. Senin eklemeyi düşündüğün bir şey varsa onu da ekle. Bu toolkit'te ayar içe aktar gibi seçeneklerde olursa iyi olur, bu sayede aynı sunucuda birden fazla proje üzerinde değişiklik yapılabilir, kullanıcının hangi proje üzerinde işlem yaptığıda her an her yerde gözükür olsun falan. Yani kapsamlıca düşün ve bunu yapalım.