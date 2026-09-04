# Laravel Server Manager – Project Conventions

## Architecture
- **Config-Driven**: Tüm ayarlar `scripts/config.sh` içinde tutulur. Hiçbir IP, şifre veya proje adı hardcode edilmez.
- **Single Responsibility**: Her script tek bir görevi yerine getirir ve `common.sh`'yi source ederek ortak fonksiyonları kullanır.
- **Multi-Project Support**: Aynı sunucuda birden fazla Laravel projesi yönetilebilir. Aktif proje her zaman ekranda görünür olmalıdır.

## Bash Script Standards
- Her script `#!/bin/bash` ile başlar.
- `set -euo pipefail` kullanılır (hata yönetimi).
- Renkli terminal çıktıları için `echo -e` ve ANSI renk kodları kullanılır.
- Fonksiyonlar try-catch mantığıyla sarmalanır (trap kullanımı).
- Tüm kullanıcı girdileri doğrulanır (input validation).

## Language
- Script içi mesajlar, menüler ve kullanıcıya gösterilen tüm metinler **Türkçe** olarak yazılır.
- Kod yorumları İngilizce veya Türkçe olabilir.

## Security
- GitHub PAT ve DB şifreleri `config.sh` içinde tutulur; bu dosya `.gitignore`'a eklenir.
- `config.sh` dosya izinleri `600` olarak ayarlanır.
