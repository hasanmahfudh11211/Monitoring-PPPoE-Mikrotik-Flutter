# Mikrotik-PPPoE-Monitor

OKE
Aplikasi monitoring user PPPoE Mikrotik berbasis Flutter dan REST API. Memudahkan monitoring, manajemen, dan analisis user PPPoE secara real-time. Dibuat untuk tugas akhir/skripsi dan kebutuhan monitoring jaringan.

---

## Daftar Isi

1.  [Fitur Utama](#fitur-utama)
2.  [Teknologi yang Digunakan](#teknologi-yang-digunakan)
3.  [Mulai Cepat (Quick Start)](#mulai-cepat-quick-start)
4.  [Panduan Deployment](#panduan-deployment)
5.  [Konfigurasi Mikrotik](#konfigurasi-mikrotik)
6.  [Fitur & Panduan Penggunaan](#fitur--panduan-penggunaan)
    *   [Auto Update System](#auto-update-system)
    *   [Router Image Feature](#router-image-feature)
    *   [Auto Backup Feature](#auto-backup-feature)
    *   [API Billing & Fixes](#api-billing--fixes)
    *   [Penanganan Duplikasi Data](#penanganan-duplikasi-data)
    *   [Perlindungan & Pemulihan Data](#perlindungan--pemulihan-data)
7.  [Keamanan (Security Notes)](#keamanan-security-notes)
8.  [Troubleshooting](#troubleshooting)
9.  [Ringkasan Perbaikan](#ringkasan-perbaikan)
10. [Lisensi & Pengembang](#lisensi--pengembang)

---

## Fitur Utama

*   **Monitoring User PPPoE**: Lihat daftar user aktif, status koneksi, profil, dan detail user secara real-time.
*   **Manajemen User**: Tambah, edit, dan hapus user PPPoE langsung dari aplikasi.
*   **Integrasi REST API**: Komunikasi dengan perangkat Mikrotik menggunakan REST API yang aman dan efisien.
*   **Log & Statistik**: Tersedia log aktivitas dan statistik penggunaan untuk analisis jaringan.
*   **UI Modern & Responsif**: Tampilan modern, mendukung dark mode, dan responsif di berbagai perangkat.
*   **Notifikasi & Error Handling**: Penanganan error yang informatif dan notifikasi status aksi.
*   **Manajemen Pembayaran**: Fitur billing untuk mencatat dan melacak pembayaran user.
*   **Manajemen ODP**: Integrasi dengan Optical Distribution Point untuk pelacakan lokasi user.
*   **Export Data**: Ekspor data user dan pembayaran ke format Excel dan PDF.
*   **Auto Update System**: System update otomatis tanpa perlu membagikan APK secara manual.

---

## Teknologi yang Digunakan

*   **Flutter** (Dart)
*   **Provider** (state management)
*   **REST API** (komunikasi dengan Mikrotik)
*   **Material Design**
*   **HTTP Client** (untuk komunikasi dengan backend)
*   **Image Picker** (untuk upload foto lokasi)
*   **PDF Generator** (untuk export laporan)

---

## Mulai Cepat (Quick Start)

Panduan cepat untuk mulai menggunakan aplikasi dalam 15 menit!

### Prerequisites

*   Mikrotik Router (RouterOS 7.9+)
*   Web Server dengan PHP & MySQL
*   Android Device untuk testing

### Setup dalam 5 Langkah

#### 1. Setup Database (3 menit)

Login ke MySQL dan import schema:

```bash
mysql -u root -p < database_schema.sql
```

Buat user database:

```sql
CREATE USER 'pppoe_user'@'localhost' IDENTIFIED BY 'password123';
GRANT ALL PRIVILEGES ON pppoe_monitor.* TO 'pppoe_user'@'localhost';
FLUSH PRIVILEGES;
```

#### 2. Configure Backend (2 menit)

Masuk ke folder api dan buat file .env:

```bash
cd api
# Buat file .env dengan isi:
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=password123
```

Set permissions: `chmod 600 .env`

#### 3. Configure Mikrotik (3 menit)

Login ke Mikrotik dan aktifkan REST API:

```bash
/ip service set www port=80 disabled=no
/user add name=api_user password=api123456 group=full
```

#### 4. Build Flutter App (5 menit)

Update API URL di `lib/services/api_service.dart` jika perlu.
Clean & build:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

#### 5. First Login (2 menit)

Buka aplikasi, masukkan credentials (IP Mikrotik, Port 80, Username api_user, Password api123456), lalu klik Login.

---

## Panduan Deployment

### Persiapan Server

**Server Backend:**
*   PHP 7.4 atau lebih tinggi
*   MySQL 5.7 atau MariaDB 10.3+
*   Apache/Nginx Web Server
*   SSL Certificate (recommended untuk production)

**Mikrotik Router:**
*   RouterOS v7.9 atau lebih tinggi (untuk REST API support)
*   Port 80/443 terbuka untuk REST API

### Setup Database

1.  Create Database `pppoe_monitor`.
2.  Import `database_schema.sql`.
3.  Create dedicated user database (jangan pakai root).

### Konfigurasi Backend API

1.  Upload folder `api` ke server (misal `/var/www/html/api`).
2.  Setup `.env` file di dalam folder api.
3.  Set permissions `chmod 755 *.php` dan `chown -R www-data:www-data .`.

### Build & Deploy Flutter App

1.  Update `lib/services/api_service.dart` dengan URL production.
2.  Build Release APK: `flutter build apk --release`.
3.  Setup Signing (Keystore) untuk production build.

---

## Konfigurasi Mikrotik

Aplikasi ini menggunakan **Mikrotik REST API** sebagai jalur komunikasi.

**Penting:**
*   Versi minimum RouterOS: **7.9**
*   Port default: **80** (HTTP) atau **443** (HTTPS)
*   User harus memiliki hak akses **api** dan **rest-api**.

**Langkah Aktivasi:**
1.  Masuk ke Mikrotik.
2.  IP > Services > Enable `www` atau `www-ssl`.
3.  System > Users > Buat user dengan group `full` atau custom group dengan policy `api, rest-api, read, write`.

---

## Fitur & Panduan Penggunaan

### Auto Update System

Sistem auto update memungkinkan aplikasi mendeteksi dan mengunduh pembaruan APK dari server secara otomatis.

**Komponen:**
*   Backend: `api/check_update.php`
*   Frontend: `UpdateService`, `UpdateDialog`

**Cara Release Update Baru:**
1.  Update version di `pubspec.yaml`.
2.  Update `api/check_update.php` dengan versi baru dan release notes.
3.  Build APK baru.
4.  Upload APK ke server (`/files/app-release.apk`).

### Router Image Feature

Menampilkan gambar router resmi dari Mikrotik berdasarkan model router yang terdeteksi.

*   Menggunakan URL resmi dari CDN Mikrotik.
*   Support 264+ model router (CCR, RB, hEX, dll).
*   Otomatis mendeteksi berdasarkan `board-name`.
*   Memiliki mekanisme fallback jika gambar tidak ditemukan.

**Debug Router Image:**
Jika gambar tidak muncul, cek `assets/router_images_online.json` dan pastikan koneksi internet tersedia. Cek console log untuk error message.

### Auto Backup Feature

Fitur backup otomatis untuk melindungi data.

*   **Automatic Backup**: Backup SQL full dibuat otomatis sebelum sinkronisasi.
*   **Scheduled Backups**: Harian (02:00) dan Mingguan (Minggu 03:00).
*   **Manual Backup**: Bisa dipicu user dari menu Restore/Backup Database.
*   **Lokasi**: Folder Download di device (`pppoe-full-backup-[router-id]-....sql`).

### API Billing & Fixes

Sistem billing telah diperbaiki untuk menangani error dengan lebih baik.

*   **Endpoint**: `api/payment_summary_operations.php`
*   **Fixes**: Type casting safe, timeout handling (15s), error messages yang user-friendly.
*   **Database**: Tabel `payments` dengan `router_id`.

### Penanganan Duplikasi Data

Jika terjadi duplikasi user karena perubahan Router ID (misal update firmware atau ganti hardware).

**Cara Fix:**
Gunakan script `api/merge_router_ids.php` untuk menggabungkan data lama ke router ID baru.

**Request:**
POST ke `api/merge_router_ids.php`
```json
{
  "old_router_id": "RB-RouterOS@...",
  "new_router_id": "SERIAL_NUMBER",
  "merge_strategy": "newest"
}
```

### Perlindungan & Pemulihan Data

**Masalah Lama**: Sinkronisasi menghapus data tambahan (WA, Lokasi) dan billing.
**Solusi Baru**:
*   Sinkronisasi rutin **MEMPERTAHANKAN** data tambahan.
*   Fitur "Prune" (hapus data yang tidak ada di Mikrotik) diproteksi dan butuh konfirmasi.
*   Backup otomatis tabel `users` dan `payments` sebelum operasi berbahaya.

**Recovery**:
Gunakan API `api/restore_backup.php` atau `api/recover_billing_data.php` untuk mengembalikan data dari backup server.

---

## Keamanan (Security Notes)

**Isu Kritis yang Telah Diperbaiki:**
*   Database credentials tidak lagi hardcoded (menggunakan `.env`).
*   File sensitif dihapus dari git history.

**Rekomendasi Keamanan (Wajib untuk Production):**
1.  **HTTPS**: Wajib gunakan HTTPS untuk API server.
2.  **API Auth**: Implementasikan API Key atau JWT untuk melindungi endpoint API.
3.  **SQL Injection**: Pastikan semua query menggunakan prepared statements.
4.  **Keystore**: Generate keystore baru untuk production signing.
5.  **Rate Limiting**: Implementasikan rate limiting di API untuk mencegah abuse.

---

## Troubleshooting

**Koneksi Timeout:**
*   Cek koneksi internet.
*   Pastikan IP Mikrotik benar dan bisa di-ping.
*   Pastikan service `www` di Mikrotik aktif.

**Username/Password Salah:**
*   Cek user di Mikrotik (`/user print`).
*   Pastikan user punya hak akses API.

**Database Connection Failed:**
*   Cek file `api/.env` di server.
*   Pastikan user database memiliki privileges yang benar.

**API Return HTML:**
*   Cek konfigurasi server web (Apache/Nginx).
*   Cek `.htaccess`.
*   Pastikan tidak ada error PHP yang ter-output sebagai HTML.

**Refresh Analyzer (VSCode):**
Jika ada error palsu di IDE, jalankan `Dart: Restart Analysis Server` atau `flutter clean`.

---

## Ringkasan Perbaikan

**Oktober 2024**
*   Fixed Merge Conflict di `odp_operations.php`.
*   Removed duplicate & temporary files.
*   Added Environment Variable support.
*   Created Database Schema.
*   Fixed Cache Implementation Bug.
*   Created Comprehensive Documentation.

**November 2025**
*   Fixed Duplicate Data issue (Merge Router ID).
*   Updated Router Image feature (JSON based).

---

## Lisensi & Pengembang

**Lisensi**: GPL-3.0

**Pengembang**:
*   Hasan Mahfudh / Husein Braithweittt
*   Email: hasanmahfudh112@gmail.com
*   Instagram: @hasan.mhfdz