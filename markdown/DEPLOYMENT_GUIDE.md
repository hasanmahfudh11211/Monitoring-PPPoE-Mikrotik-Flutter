# 🚀 Panduan Deployment Mikrotik PPPoE Monitor

Panduan lengkap untuk deployment aplikasi Mikrotik PPPoE Monitor ke production.

---

## 📋 Daftar Isi

1. [Persiapan Server](#persiapan-server)
2. [Setup Database](#setup-database)
3. [Konfigurasi Backend API](#konfigurasi-backend-api)
4. [Build & Deploy Flutter App](#build--deploy-flutter-app)
5. [Konfigurasi Mikrotik](#konfigurasi-mikrotik)
6. [Testing](#testing)
7. [Troubleshooting](#troubleshooting)

---

## 🖥️ Persiapan Server

### Minimum Requirements

**Server Backend:**
- PHP 7.4 atau lebih tinggi
- MySQL 5.7 atau MariaDB 10.3+
- Apache/Nginx Web Server
- SSL Certificate (recommended untuk production)
- Minimal 512MB RAM
- 1GB Storage

**Mikrotik Router:**
- RouterOS v7.9 atau lebih tinggi (untuk REST API support)
- Port 80/443 terbuka untuk REST API
- User dengan full access privileges

**Development Machine:**
- Flutter SDK 3.2.3+
- Android SDK (untuk build Android)
- Xcode (untuk build iOS - MacOS only)

---

## 💾 Setup Database

### 1. Create Database

Login ke MySQL/MariaDB:

```bash
mysql -u root -p
```

Import schema:

```sql
source database_schema.sql
```

Atau manual:

```bash
mysql -u root -p < database_schema.sql
```

### 2. Create Database User (Recommended)

**JANGAN gunakan root untuk production!**

```sql
-- Create dedicated user
CREATE USER 'pppoe_user'@'localhost' IDENTIFIED BY 'YourSecurePasswordHere';

-- Grant privileges
GRANT ALL PRIVILEGES ON pppoe_monitor.* TO 'pppoe_user'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;
```

### 3. Verify Database

```sql
USE pppoe_monitor;
SHOW TABLES;
```

Expected output:
```
+---------------------------+
| Tables_in_pppoe_monitor   |
+---------------------------+
| detail_pelanggan          |
| odp                       |
| payments                  |
| users                     |
+---------------------------+
```

---

## 🔧 Konfigurasi Backend API

### 1. Upload Files ke Server

**Via FTP/SFTP:**
```bash
# Upload folder 'api' ke server
scp -r api/ user@yourserver.com:/var/www/html/
```

**Via cPanel:**
- Login ke cPanel
- File Manager → public_html
- Upload folder `api`

### 2. Setup Environment Variables

**Opsi A: Menggunakan file .env (Recommended)**

Buat file `api/.env`:

```bash
cd /var/www/html/api
nano .env
```

Isi file `.env`:

```env
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=YourSecurePasswordHere
```

**Set permissions:**
```bash
chmod 600 .env
chown www-data:www-data .env
```

**Opsi B: Server Environment Variables**

Edit Apache config:
```apache
<VirtualHost *:80>
    SetEnv DB_HOST "localhost"
    SetEnv DB_NAME "pppoe_monitor"
    SetEnv DB_USER "pppoe_user"
    SetEnv DB_PASS "YourSecurePasswordHere"
</VirtualHost>
```

### 3. Set Permissions

```bash
cd /var/www/html/api
chmod 755 *.php
chown -R www-data:www-data .
```

### 4. Setup .htaccess (Optional - untuk security)

Buat file `api/.htaccess`:

```apache
# Disable directory listing
Options -Indexes

# Protect .env file
<Files ".env">
    Order allow,deny
    Deny from all
</Files>

# Enable CORS (jika diperlukan)
Header set Access-Control-Allow-Origin "*"
Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
Header set Access-Control-Allow-Headers "Content-Type, Authorization"

# Force HTTPS (jika sudah setup SSL)
# RewriteEngine On
# RewriteCond %{HTTPS} off
# RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

### 5. Test API Endpoints

```bash
# Test connection
curl http://yourserver.com/api/get_all_users.php

# Expected: {"success":true,"data":[...]}
```

---

## 📱 Build & Deploy Flutter App

### 1. Update API Base URL

Edit `lib/services/api_service.dart`:

```dart
class ApiService {
  static const String baseUrl = 'https://yourserver.com/api'; // Change this!
  // ...
}
```

### 2. Build Android APK

**Release Build:**

```bash
# Clean previous builds
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

**App Bundle (untuk Google Play Store):**

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 3. Setup Signing (untuk production)

**Generate keystore (jika belum ada):**

```bash
keytool -genkey -v -keystore ~/my-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias my-key-alias
```

**Edit `android/key.properties`:**

```properties
storePassword=YourKeystorePassword
keyPassword=YourKeyPassword
keyAlias=my-key-alias
storeFile=/path/to/my-release-key.jks
```

**Edit `android/app/build.gradle.kts`:**

```kotlin
android {
    // ...
    signingConfigs {
        create("release") {
            storeFile = file(keystoreProperties["storeFile"]!!)
            storePassword = keystoreProperties["storePassword"] as String
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 4. Distribute App

**Option A: Direct Distribution**
- Share APK file langsung ke user
- Install dengan enable "Unknown Sources"

**Option B: Google Play Store**
1. Create Developer Account ($25 one-time fee)
2. Upload app bundle (.aab)
3. Fill app details & screenshots
4. Submit for review

**Option C: Internal Testing**
- Upload ke Google Drive
- Share link dengan user
- Use Firebase App Distribution

---

## ⚙️ Konfigurasi Mikrotik

### 1. Update RouterOS

Pastikan RouterOS versi 7.9+:

```
/system package update check-for-updates
/system package update download
/system reboot
```

### 2. Enable REST API

```
# Enable www service
/ip service enable www

# Set port (default 80)
/ip service set www port=80

# For HTTPS (recommended)
/ip service enable www-ssl
/ip service set www-ssl port=443
```

### 3. Create API User

**JANGAN gunakan admin user!**

```
# Create group dengan limited access
/user group add name=api_access policy=read,write,api,rest-api

# Create user
/user add name=api_user password=SecurePassword123 group=api_access

# Verify
/user print
```

### 4. Firewall Rules (jika diperlukan)

```
# Allow API access dari IP tertentu
/ip firewall filter add chain=input protocol=tcp dst-port=80 \
  src-address=your-server-ip action=accept \
  comment="Allow REST API"

# Drop other requests (optional)
/ip firewall filter add chain=input protocol=tcp dst-port=80 \
  action=drop comment="Block other API access"
```

### 5. Test REST API

```bash
# Test dari terminal
curl -u api_user:SecurePassword123 \
  http://router-ip/rest/system/identity

# Expected: {"name":"YourRouter"}
```

---

## 🧪 Testing

### Backend API Testing

**1. Test Database Connection:**

```bash
curl http://yourserver.com/api/get_all_users.php
```

**2. Test Payment Summary:**

```bash
curl http://yourserver.com/api/get_payment_summary.php
```

**3. Test ODP Operations:**

```bash
curl http://yourserver.com/api/odp_operations.php
```

### Mobile App Testing

**1. Test Connection:**
- Open app
- Login dengan credentials Mikrotik
- Verify dashboard loads

**2. Test Features:**
- ✅ View active sessions
- ✅ Add new user
- ✅ Edit user
- ✅ Delete user
- ✅ Add payment
- ✅ View payment summary
- ✅ Export data

**3. Performance Testing:**
- Test dengan banyak user (100+)
- Monitor memory usage
- Check response time

---

## 🐛 Troubleshooting

### Problem: API Returns HTML Instead of JSON

**Symptom:**
```
Server mengembalikan halaman HTML bukan data JSON
```

**Solution:**
1. Check `.htaccess` rules
2. Verify API authentication tidak redirect ke login
3. Test dengan Postman/curl dulu

### Problem: Database Connection Failed

**Symptom:**
```
DB connect failed: Access denied for user
```

**Solution:**
1. Verify database credentials di `.env` atau `config.php`
2. Check user permissions:
   ```sql
   SHOW GRANTS FOR 'pppoe_user'@'localhost';
   ```
3. Reset password:
   ```sql
   ALTER USER 'pppoe_user'@'localhost' IDENTIFIED BY 'NewPassword';
   FLUSH PRIVILEGES;
   ```

### Problem: Mikrotik Connection Refused

**Symptom:**
```
Koneksi ke router gagal karena Port tidak dapat diakses
```

**Solution:**
1. Verify REST API service aktif:
   ```
   /ip service print
   ```
2. Check firewall rules
3. Test dengan curl dari server yang sama
4. Pastikan port benar (80 atau 443)

### Problem: CORS Error di Browser

**Symptom:**
```
Access to XMLHttpRequest blocked by CORS policy
```

**Solution:**
Add headers di PHP:
```php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type");
```

### Problem: App Crashes on Startup

**Solution:**
1. Check logcat:
   ```bash
   adb logcat | grep Flutter
   ```
2. Verify all dependencies installed:
   ```bash
   flutter pub get
   flutter clean
   flutter build apk
   ```
3. Check for null safety errors

---

## 📊 Monitoring & Maintenance

### Database Backup

**Daily backup script:**

```bash
#!/bin/bash
# backup-db.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/mysql"
DB_NAME="pppoe_monitor"

mysqldump -u pppoe_user -p${DB_PASS} ${DB_NAME} | gzip > \
  ${BACKUP_DIR}/${DB_NAME}_${DATE}.sql.gz

# Keep only last 30 days
find ${BACKUP_DIR} -name "*.sql.gz" -mtime +30 -delete
```

**Setup cron job:**
```bash
crontab -e

# Add line (daily at 2 AM)
0 2 * * * /path/to/backup-db.sh
```

### Log Rotation

**Setup logrotate untuk PHP errors:**

```bash
# /etc/logrotate.d/php-app
/var/log/php/*.log {
    daily
    missingok
    rotate 14
    compress
    notifempty
    create 0640 www-data www-data
}
```

### Performance Monitoring

**Check database size:**
```sql
SELECT 
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'pppoe_monitor'
GROUP BY table_schema;
```

**Optimize tables:**
```sql
OPTIMIZE TABLE users, payments, odp;
```

---

## 🔐 Security Checklist

Before going to production:

- [ ] Database password di-encrypt dengan environment variables
- [ ] API menggunakan HTTPS (SSL certificate installed)
- [ ] Mikrotik user khusus untuk API (bukan admin)
- [ ] Firewall rules di Mikrotik untuk restrict API access
- [ ] `.env` file permissions set to 600
- [ ] Database user dengan minimal required privileges
- [ ] Backup strategy implemented
- [ ] Error logging configured
- [ ] Rate limiting di API (optional)
- [ ] API authentication dengan token/API key (optional)

---

## 📞 Support & Resources

**Documentation:**
- [Mikrotik REST API Docs](https://help.mikrotik.com/docs/display/ROS/REST+API)
- [Flutter Deployment Guide](https://docs.flutter.dev/deployment/android)
- [MySQL Security Best Practices](https://dev.mysql.com/doc/refman/8.0/en/security-best-practices.html)

**Contact:**
- Email: hasanmahfudh112@gmail.com
- Instagram: [@hasan.mhfdz](https://www.instagram.com/hasan.mhfdz)

---

## 📝 Changelog

### Version 1.0.0 (October 2024)
- Initial release
- Mikrotik REST API integration
- User management features
- Payment tracking system
- ODP management
- Export to Excel & PDF

---

**Last Updated:** October 24, 2024

