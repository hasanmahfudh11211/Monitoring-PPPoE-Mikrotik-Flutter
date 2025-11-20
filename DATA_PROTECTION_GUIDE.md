# Panduan Perlindungan Data

Dokumen ini menjelaskan langkah-langkah yang telah diimplementasikan untuk melindungi data Anda dari kehilangan saat sinkronisasi.

## Masalah yang Terjadi Sebelumnya

Sebelumnya, ketika Anda mengklik "sinkron semua user", sistem akan:
1. Mengupdate username, password, dan profile dari Mikrotik
2. **Menghapus** data tambahan seperti WhatsApp, maps, dan foto yang sudah Anda masukkan secara manual
3. **Menghapus** data billing (pembayaran) karena keterkaitan dengan data user

Ini terjadi karena proses sinkronisasi hanya mengirim data dasar dari Mikrotik tanpa mempertahankan data tambahan yang sudah ada, dan karena constraint `ON DELETE CASCADE` pada tabel pembayaran.

## Perbaikan yang Telah Dilakukan

### 1. Sinkronisasi yang Aman
Proses sinkronisasi sekarang:
- **Mempertahankan** data tambahan (WhatsApp, maps, foto, tanggal dibuat) yang sudah ada
- Hanya mengupdate field dasar (password dan profile) dari Mikrotik
- Tidak lagi mengaktifkan fitur "prune" secara otomatis

### 2. Perlindungan Prune
Fitur "prune" (penghapusan data) sekarang memiliki proteksi:
- Tidak akan dijalankan jika tidak ada data yang diterima
- Memberi peringatan jika akan menghapus terlalu banyak data
- Membuat backup otomatis sebelum operasi prune besar-besaran

### 3. Backup Otomatis
Sistem sekarang secara otomatis membuat backup tabel users:
- Sebelum operasi yang berpotensi menghapus banyak data
- Dengan nama tabel berformat: `users_backup_YYYYMMDD_HHMMSS`

### 4. Proteksi Data Billing
Data billing (pembayaran) sekarang lebih aman:
- Dibuat backup secara terpisah sebelum operasi prune
- Dapat dipulihkan menggunakan prosedur khusus
- Tidak langsung terhapus saat user dihapus (dengan modifikasi constraint)

## Cara Menggunakan Sinkronisasi dengan Aman

### Sinkronisasi Rutin (Disarankan)
- Digunakan untuk memperbarui data dari Mikrotik
- Tidak akan menghapus data tambahan Anda
- Aman digunakan kapan saja

### Sinkronisasi dengan Prune (Hati-hati!)
Hanya gunakan jika Anda benar-benar mengerti konsekuensinya:
- Akan menghapus data user yang tidak ada di Mikrotik
- Sebaiknya hanya digunakan saat setup awal atau migrasi

## Cara Mengecek dan Mengelola Backup

### Melihat Daftar Backup Users
```bash
curl -X GET https://your-domain.com/api/restore_backup.php
```

### Mengembalikan Data Users dari Backup
```bash
curl -X POST https://your-domain.com/api/restore_backup.php \
     -H "Content-Type: application/json" \
     -d '{"router_id": "YOUR_ROUTER_ID", "backup_table": "users_backup_YYYYMMDD_HHMMSS"}'
```

### Melihat Daftar Backup Payments
```bash
curl -X GET https://your-domain.com/api/recover_billing_data.php
```

### Mengembalikan Data Payments dari Backup
```bash
curl -X POST https://your-domain.com/api/recover_billing_data.php \
     -H "Content-Type: application/json" \
     -d '{"router_id": "YOUR_ROUTER_ID", "backup_table": "payments_backup_YYYYMMDD_HHMMSS"}'
```

## Rekomendasi untuk Mencegah Kehilangan Data

1. **Backup Rutin**: Lakukan backup database secara berkala
2. **Verifikasi Data**: Selalu cek data setelah sinkronisasi
3. **Gunakan Sinkronisasi Rutin**: Hindari penggunaan prune kecuali benar-benar diperlukan
4. **Catat Perubahan**: Catat tanggal dan waktu sinkronisasi penting

## Jika Terjadi Kehilangan Data Lagi

1. Cek tabel backup di database dengan format `users_backup_*` dan `payments_backup_*`
2. Gunakan API restore untuk mengembalikan data
3. Hubungi tim pengembang jika memerlukan bantuan lebih lanjut

## Pertanyaan Umum

**Q: Apakah data WhatsApp, maps, dan foto saya aman sekarang?**
A: Ya, proses sinkronisasi rutin sekarang tidak akan menghapus data tambahan tersebut.

**Q: Apakah data billing saya juga dilindungi?**
A: Ya, sistem sekarang membuat backup terpisah untuk data billing dan menyediakan cara untuk memulihkannya.

**Q: Kapan saya boleh menggunakan prune?**
A: Hanya saat setup awal atau migrasi data, dan pastikan Anda memiliki backup terlebih dahulu.

**Q: Bagaimana cara memastikan data saya tidak hilang?**
A: Lakukan sinkronisasi rutin tanpa prune, dan buat backup database secara berkala.