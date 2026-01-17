# Implementasi Sistem: Mikrotik Monitor

## H. Lingkungan Implementasi

Implementasi sistem "Mikrotik Monitor" dilakukan menggunakan lingkungan pengembangan (development environment) dan lingkungan operasional (production environment) sebagai berikut:

### 1. Perangkat Keras (Hardware)

- **Laptop Development:**
  - Processor: Intel Core i5 / AMD Ryzen 5 setara.
  - RAM: 8 GB (rekomendasi 16 GB).
  - Storage: SSD 256 GB.
- **Perangkat Uji (Mobile):**
  - Smartphone Android (Minimal Android 8.0 Oreo).
  - Koneksi Internet (WiFi/4G).
- **Perangkat Jaringan:**
  - RouterBoard Mikrotik (model RB750r2 atau setara untuk pengujian).

### 2. Perangkat Lunak (Software)

- **Sistem Operasi:** Windows 10/11.
- **Code Editor:** Visual Studio Code (VS Code).
- **SDK:** Flutter SDK (versi 3.5.0 atau terbaru).
- **Bahasa Pemrograman:** Dart.
- **Manajemen Database:** SQLite (lokal di HP) dan MySQL (opsional untuk sinkronisasi log).
- **Tools Tambahan:**
  - Git (Version Control).
  - Postman (Pengujian API Manual).
  - Winbox (Verifikasi data di Router).

## I. Implementasi Antarmuka (UI)

Implementasi antarmuka merupakan realisasi dari rancangan desain UI/UX. Berikut adalah deskripsi halaman-halaman utama yang telah dibangun:

1.  **Halaman Login (`LoginScreen`)**

    - Halaman pertama yang muncul saat aplikasi dibuka.
    - Terdapat form input untuk: IP Address, Username, Password, dan Port API (Default: 8728).
    - Tombol "Connect" untuk memulai koneksi ke router.
    - Fitur "Riwayat Login" untuk memilih router yang pernah diakses sebelumnya.

2.  **Dashboard Utama (`DashboardScreen`)**

    - Menampilkan ringkasan status router secara _real-time_.
    - **Resource Card:** Menampilkan persentase CPU Load, penggunaan Memory (RAM), dan Uptime router.
    - **Traffic Monitor:** Grafik garis (Line Chart) yang bergerak dinamis menampilkan trafik Upload (Tx) dan Download (Rx) dari interface utama (misal: ether1).
    - **Grid Menu:** Akses cepat ke fitur PPPoE, Hotspot, Logs, Billing, dan System.

3.  **Halaman Manajemen PPPoE (`SecretsActiveScreen`)**

    - **Tab Active:** Menampilkan daftar user yang sedang online (terkoneksi), lengkap dengan IP Address dan durasi uptime.
    - **Tab Secrets:** Menampilkan daftar semua akun pelanggan yang terdaftar.
    - **Fitur CRUD:** Terdapat tombol Floating Action Button (+) untuk menambah user baru. Klik pada item user untuk mengedit atau menghapus.

4.  **Halaman Billing (`BillingScreen`)**
    - Menampilkan daftar tagihan pelanggan.
    - Status pembayaran ditandai dengan warna (Lunas/Belum).
    - Fitur untuk mengirim bukti bayar atau tagihan via WhatsApp.

## J. Implementasi Kode Program

Aplikasi dibangun menggunakan framework Flutter dengan struktur proyek sebagai berikut:

### 1. Struktur Folder

```text
lib/
├── api/                # Skrip PHP untuk backend (opsional/legacy)
├── models/             # Model data (User, Log, Billing)
├── providers/          # State Management (MikrotikProvider, RouterSession)
├── screens/            # Tampilan UI (Dashboard, Login, dll)
├── services/           # Logika bisnis & API Call (MikrotikService)
├── utils/              # Fungsi bantuan (Format mata uang, tanggal)
└── main.dart           # Entry point aplikasi
```

### 2. Modul Koneksi API (Dual Strategy)

Aplikasi menerapkan strategi koneksi ganda untuk kompatibilitas maksimal:

- **REST API (`MikrotikService`):** Menggunakan HTTP Request ke `/rest/` (Port 80/443). Lebih stabil dan mudah di-debug.
- **Native API (`MikrotikNativeService`):** Menggunakan Socket TCP ke API Port (Default 8728). Digunakan sebagai fallback atau jika REST API tidak aktif.

```dart
// Contoh pemilihan service di RouterSessionProvider
if (useNativeApi || port == '8728') {
  _service = MikrotikNativeService(...);
} else {
  _service = MikrotikService(...);
}
```

### 3. State Management (`Provider`)

Aplikasi menggunakan `Provider` untuk mengelola state global, seperti data sesi router yang sedang aktif, sehingga data tidak hilang saat berpindah layar.

```dart
class RouterSessionProvider with ChangeNotifier {
  MikrotikService? _service;

  // Getter untuk service yang aktif
  MikrotikService? get service => _service;

  void setService(MikrotikService service) {
    _service = service;
    notifyListeners(); // Update semua UI yang mendengarkan
  }
}
```

### 4. Background Services

Untuk memastikan monitoring berjalan real-time, aplikasi menggunakan dua service latar belakang:

- **`LiveMonitorService`:** Menggunakan `FlutterLocalNotificationsPlugin` untuk menampilkan notifikasi persisten berisi CPU, Memory, dan Trafik Interface setiap 1 detik.
- **`LogSyncService`:** Berjalan setiap 10 detik untuk mengambil log terbaru dari router, mengirimnya ke backend PHP, dan memunculkan notifikasi lokal jika ada event kritis (misal: User PPPoE Disconnected).

## K. Pengujian Sistem (Black Box Testing)

Pengujian dilakukan dengan metode _Black Box Testing_ untuk memastikan fungsionalitas input dan output sesuai harapan tanpa melihat kode internal.

| No  | Skenario Pengujian    | Test Case                                                            | Hasil yang Diharapkan                                           | Hasil Pengujian | Kesimpulan |
| :-- | :-------------------- | :------------------------------------------------------------------- | :-------------------------------------------------------------- | :-------------- | :--------- |
| 1   | **Login Berhasil**    | Input IP, User, Pass yang benar, lalu klik Connect.                  | Masuk ke Dashboard dan tampil data resource.                    | Sesuai Harapan  | **Valid**  |
| 2   | **Login Gagal**       | Input Password salah.                                                | Muncul pesan error "Authentication Failed".                     | Sesuai Harapan  | **Valid**  |
| 3   | **Monitoring Live**   | Amati grafik trafik saat melakukan download file besar di PC client. | Grafik pada aplikasi naik sesuai aktivitas download.            | Sesuai Harapan  | **Valid**  |
| 4   | **Tambah User PPPoE** | Input nama "user_test" dan password, pilih profile, simpan.          | Data muncul di list Secrets dan bisa login di perangkat client. | Sesuai Harapan  | **Valid**  |
| 5   | **Hapus User**        | Geser/Klik hapus pada "user_test".                                   | Data hilang dari list Secrets.                                  | Sesuai Harapan  | **Valid**  |
| 6   | **Cek Tagihan**       | Buka menu Billing.                                                   | Tampil daftar pelanggan yang belum bayar bulan ini.             | Sesuai Harapan  | **Valid**  |
| 7   | **Logout**            | Klik tombol Logout di menu setting.                                  | Kembali ke halaman Login dan sesi diputus.                      | Sesuai Harapan  | **Valid**  |

## L. Kesimpulan Implementasi

Implementasi sistem "Mikrotik Monitor" telah berhasil dilakukan sesuai dengan rancangan. Aplikasi mampu berjalan pada perangkat Android dan terhubung dengan baik ke Router Mikrotik untuk melakukan fungsi monitoring dan manajemen dasar. Pengujian menunjukkan bahwa fitur-fitur utama berjalan stabil dan responsif.
