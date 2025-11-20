const String changelogContent = '''
# Mikrotik Monitor App — Changelog

---

## 🎨 UI/UX Enhancement Update — Juni 2025

### 💄 Secrets Active Screen Improvement
- Redesign tampilan detail user:
  - Single container dengan divider sebagai pemisah
  - Spacing dan padding yang lebih compact
  - Icon berwarna sesuai tema aplikasi
  - Real-time uptime di popup detail
- Peningkatan visual:
  - Konsistensi border radius
  - Warna dan kontras yang lebih baik
  - Alignment yang lebih rapi
  - Optimasi tampilan untuk item dengan tombol copy

### 🔐 Security Enhancement
- Menghapus fitur copy password untuk keamanan
- Menyederhanakan tampilan dengan menghilangkan Caller ID dan Last Caller ID
- Mempertahankan toggle visibility untuk password

### 📱 Layout Optimization
- Penyesuaian padding dan margin
- Peningkatan responsivitas
- Konsistensi ukuran font
- Perbaikan alignment untuk semua elemen

---

## 📦 Version 1.1.0 — 12 Juni 2025

### 🔄 Traffic Monitor Development (Phase 1)
- Menambahkan **Traffic Screen** untuk memantau interface secara real-time.
- Fitur utama:
  - Dropdown untuk memilih interface
  - Status indikator (Running / Stopped)
  - Monitoring trafik secara langsung
  - Auto-refresh setiap 1 detik

### 🎨 Traffic Display Enhancement (Phase 2)
- Redesign tampilan trafik:
  - Layout card modern dengan pemisah vertikal elegan
  - TX Rate (warna oranye) & RX Rate (warna biru)
  - Ukuran angka besar (42px), dengan satuan otomatis (Mbps/Kbps)
- Format angka yang cerdas:
  - Konversi otomatis ke TB / GB / MB / KB
  - Format paket: B / K / M
  - Pembulatan angka:
    - > 100: dibulatkan (cth: 235 GB)
    - 10–100: 1 desimal (cth: 45.5 GB)
    - < 10: 2 desimal (cth: 8.45 GB)
- Menampilkan informasi interface lengkap:
  - Nama dan tipe interface
  - MAC Address, MTU
  - Statistik total traffic

### ✨ Visual Enhancement (Phase 3)
- Desain kartu terpadu:
  - Latar putih transparan
  - Border radius konsisten
  - Spasi dan padding optimal
- Peningkatan tipografi:
  - Ukuran font proporsional
  - Berat font yang seimbang
  - Align teks yang rapi
  - Kontras warna yang baik
- Indikator status yang jelas dan intuitif:
  - Ikon minimalis (🟢/🔴)
  - Warna latar sesuai status

---

## 🌓 Dark Mode & UI Improvements — Mei 2024

### 🌙 Initial Dark Mode (Phase 1)
- Menambahkan `ThemeProvider` untuk pengelolaan tema
- Tombol toggle dark mode di halaman Settings
- Menyimpan preferensi pengguna dengan `SharedPreferences`

### 🎨 Dark Mode Full Integration (Phase 2)
- Widget `GradientContainer` untuk latar yang konsisten
- Gradien warna sesuai tema:
  - **Light Mode:** Biru ke putih (2196F3 → 64B5F6 → BBDEFB → white)
  - **Dark Mode:** Abu-abu gelap (grey[900] → grey[800] → grey[700])
- Diterapkan ke seluruh halaman:
  - Login, Dashboard, Tambah, Secrets, Resource, Settings

### 🧪 Dark Mode Enhancement (Phase 3)
- Peningkatan kontras dan keterbacaan teks
- Warna UI elements disesuaikan:
  - Dialog, Snackbar, Form, dan Card
- Warna ikon & tombol diperhalus
- Transisi tema lebih halus

### 🖥️ System Resource UI Overhaul (Phase 4)
- Tata ulang komponen:
  - Card utama untuk **System Identity**
  - 4 metric box: Board Name, CPU Load, Count, Frequency
  - Detail system di kartu individual
- Peningkatan tampilan visual:
  - Radius & elevasi card adaptif
  - Icon background transparan
  - Spasi & padding optimal
- Penyesuaian tema:
  - AppBar transparan
  - Gradien seragam
  - Kontras warna diperbaiki

---

## 👨‍💻 Developer & Feature Update

### 🔧 General Improvements
- Responsivitas UI lebih baik
- Performa ditingkatkan
- Konsistensi desain aplikasi
- Keterbacaan teks optimal
- Prinsip **Material Design** diterapkan lebih dalam

### 🔍 Technical Enhancements
- Manajemen state yang tepat
- Penggunaan `SharedPreferences` untuk penyimpanan lokal
- Optimasi widget tree dan sistem tema

### 📤 Feature Adjustments
- Penghapusan fitur auto-refresh dari Settings
- Retain: Toggle notifikasi

### 🆔 Developer Info
- Nama pengembang diperbarui: **@hasan.mhfdz**

---
'''; 