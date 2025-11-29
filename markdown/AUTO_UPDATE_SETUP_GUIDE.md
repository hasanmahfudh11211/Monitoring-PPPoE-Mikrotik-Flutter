# 🚀 Auto Update System Setup Guide

## 📋 Overview

Sistem auto update memungkinkan aplikasi Flutter mendeteksi dan mengunduh pembaruan APK dari server Anda secara otomatis, tanpa perlu membagikan APK secara manual.

---

## 📁 Files Yang Dibuat

### **Backend (PHP)**
```
api/
├── check_update.php         # API endpoint untuk cek update
└── config.php               # Database config (sudah ada)
```

### **Frontend (Flutter)**
```
lib/
├── services/
│   └── update_service.dart   # Service untuk cek & download update
├── widgets/
│   └── update_dialog.dart    # UI dialog untuk update
└── screens/
    └── setting_screen.dart   # Tambahan tombol Check for Updates
```

---

## 🔧 Setup Server

### **1. Upload API File**

Upload file `api/check_update.php` ke server Anda di:
```
https://cmmnetwork.online/api/check_update.php
```

### **2. Buat Direktori untuk APK**

```bash
# Via SSH/telnet ke server
cd /var/www/html  # atau path sesuai server Anda

# Buat folder files
mkdir -p files

# Set permission
chmod 755 files
```

### **3. Upload APK ke Server**

Setelah build APK:
```bash
flutter build apk --release
```

Upload APK ke:
```
https://cmmnetwork.online/files/app-release.apk
```

---

## 🔄 Cara Release Update Baru

### **Step 1: Update Version di pubspec.yaml**

```yaml
# pubspec.yaml
version: 1.0.1+2  # Tingkatkan version & build number
```

### **Step 2: Update API check_update.php**

Edit file `api/check_update.php`:
```php
const LATEST_VERSION = '1.0.1';
const LATEST_BUILD_NUMBER = 2;
const LATEST_APK_URL = 'https://cmmnetwork.online/files/app-release.apk';

const RELEASE_NOTES = [
    [
        'version' => '1.0.1',
        'build' => 2,
        'date' => '2025-11-02',  // Tanggal update
        'notes' => [
            'Fix bug billing filter',
            'Perbaikan tampilan dashboard',
            'Optimasi performa',
        ]
    ],
    // ... versi sebelumnya
];
```

### **Step 3: Upload ke Server**

```bash
# Build APK baru
flutter build apk --release

# Upload ke server (pilih salah satu cara)
# Cara 1: Via FTP
# Upload build/app/outputs/flutter-apk/app-release.apk
# Ke: /var/www/html/files/app-release.apk

# Cara 2: Via SCP
scp build/app/outputs/flutter-apk/app-release.apk user@cmmnetwork.online:/var/www/html/files/

# Cara 3: Via SFTP
# Gunakan FileZilla/WinSCP
```

### **Step 4: Test Update**

1. Install versi lama di device
2. Buka aplikasi > Settings
3. Klik "Check for Updates"
4. Pastikan dialog update muncul dengan benar

---

## 🎯 Cara Kerja Sistem

### **Flow Update:**

```
1. User klik "Check for Updates" di Settings
   ↓
2. Flutter kirim request ke check_update.php
   {
     "current_version": "1.0.0",
     "current_build": 1
   }
   ↓
3. Server cek versi terbaru
   ↓
4. Server return JSON:
   {
     "success": true,
     "update_available": true,
     "latest_version": "1.0.1",
     "latest_build": 2,
     "apk_url": "https://cmmnetwork.online/files/app-release.apk",
     "apk_size": 25123456,
     "release_notes": [...]
   }
   ↓
5. Flutter tampilkan UpdateDialog
   ↓
6. User klik "DOWNLOAD"
   ↓
7. Browser terbuka & download APK
   ↓
8. User install APK secara manual
```

---

## ⚙️ Konfigurasi

### **Force Update (Update Wajib)**

Untuk memaksa user update ke versi tertentu, edit `check_update.php`:

```php
// Versi minimum yang WAJIB diupdate
const MINIMUM_REQUIRED_VERSION = '1.0.1';
```

User dengan versi < 1.0.1 akan **tidak bisa** dismiss dialog update.

### **Optional Update (Update Opsional)**

Semua versi >= MINIMUM_REQUIRED_VERSION adalah update opsional:
- Dialog bisa ditutup dengan tombol "NANTI"
- User bisa skip update

---

## 📱 Testing Checklist

- [ ] Build APK versi 1.0.0+1
- [ ] Install di device (versi lama)
- [ ] Upload APK versi baru ke server
- [ ] Update `check_update.php` dengan versi baru
- [ ] Buka aplikasi > Settings > "Check for Updates"
- [ ] Verifikasi dialog update muncul
- [ ] Verifikasi release notes terlihat benar
- [ ] Test download APK
- [ ] Test install APK
- [ ] Verifikasi versi terbaru terpasang
- [ ] Test dengan versi terbaru (harusnya "sudah menggunakan versi terbaru")

---

## 🔒 Security Notes

### **1. HTTPS Wajib untuk Production**

APK download harus via HTTPS:
```php
const LATEST_APK_URL = 'https://cmmnetwork.online/files/app-release.apk';
```

### **2. Signature Verification (Recommended)**

Untuk extra security, verifikasi signature APK sebelum install:
```bash
# Get APK signature
jarsigner -verify -verbose -certs app-release.apk

# Compare dengan versi sebelumnya
```

### **3. Rate Limiting**

Tambahkan rate limiting di `check_update.php` untuk prevent abuse:
```php
// Check max 10 requests per hour per IP
// Implement with Redis/Memcached
```

---

## 📊 Monitoring

### **Track Update Downloads**

Tambahkan logging di `check_update.php`:
```php
// Log ke file atau database
$logData = [
    'timestamp' => date('Y-m-d H:i:s'),
    'ip' => $_SERVER['REMOTE_ADDR'],
    'current_version' => $clientVersion,
    'current_build' => $clientBuild,
];
file_put_contents('update_logs.txt', json_encode($logData) . "\n", FILE_APPEND);
```

### **Analytics Dashboard**

Buat dashboard sederhana untuk monitor:
- Berapa user yang sudah update
- Berapa user yang masih pakai versi lama
- Download stats per version

---

## 🐛 Troubleshooting

### **"Gagal memeriksa update"**

**Penyebab:**
- Server API tidak accessible
- Base URL salah di Settings > API Configuration
- Network error

**Solusi:**
1. Cek Base URL di Settings
2. Test endpoint di browser: `https://cmmnetwork.online/api/check_update.php`
3. Cek internet connection

### **"APK corrupt" setelah download**

**Penyebab:**
- Upload APK gagal / incomplete
- Server permission salah

**Solusi:**
1. Re-upload APK
2. Cek file size match dengan di server
3. Cek file permissions: `chmod 644 app-release.apk`

### **Dialog tidak muncul**

**Penyebab:**
- JSON response salah format
- Parse error di Flutter

**Solusi:**
1. Cek response dari server via browser
2. Cek console log di Flutter
3. Pastikan JSON valid

---

## 📝 Release Notes Template

```php
const RELEASE_NOTES = [
    [
        'version' => '1.0.2',
        'build' => 3,
        'date' => '2025-11-03',
        'notes' => [
            '✨ New Features:',
            '   • Fitur billing baru',
            '   • Dark mode improvements',
            '',
            '🐛 Bug Fixes:',
            '   • Fix crash di ODP screen',
            '   • Fix filter billing',
            '',
            '⚡ Performance:',
            '   • Optimasi loading time',
            '   • Reduce memory usage',
        ]
    ],
];
```

---

## 🎉 Manfaat Sistem Ini

✅ **No Manual Distribution**
- Tidak perlu bagikan APK via WhatsApp/Email
- User dapat update dengan 1 klik

✅ **Version Control**
- Track siapa yang sudah update
- Force update untuk security fixes

✅ **Better UX**
- Release notes terlihat jelas
- Size info membantu user decide

✅ **Cost Effective**
- Gratis (hanya perlu hosting)
- Unlimited downloads

---

## 📞 Support

Jika ada masalah:
1. Cek log di `update_logs.txt`
2. Test endpoint di browser
3. Cek Flutter console untuk error
4. Verify file permissions

---

**Generated:** 2025-11-02  
**Version:** 1.0.0  
**Status:** ✅ Ready for Production




















