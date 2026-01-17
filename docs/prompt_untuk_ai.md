# KUMPULAN PROMPT UML GRANULAR (SATU PER SATU)

Dokumen ini berisi prompt untuk men-generate diagram UML secara **terpisah untuk setiap fitur dan aksi**. Gunakan ini jika Anda ingin diagram yang sangat spesifik dan mendetail untuk setiap proses.

---

## A. USE CASE DIAGRAM (PER FITUR)

### 1. Use Case: Autentikasi

**Prompt:**

> Buatkan diagram Use Case khusus untuk fitur **"Autentikasi"**.
> **Aktor:** Administrator.
> **Use Case:**
>
> - Login (Input IP, User, Pass).
> - Simpan Riwayat Login (SharedPrefs).
> - Logout (Hapus Sesi).
> - Validasi Koneksi (Include ke Login).
> - Auto-Login (Cek Sesi Tersimpan).

### 2. Use Case: Monitoring Dashboard & Live Monitor

**Prompt:**

> Buatkan diagram Use Case khusus untuk fitur **"Monitoring Dashboard & Live Monitor"**.
> **Aktor:** Administrator.
> **Use Case:**
>
> - Lihat Resource System (CPU, Memory, Uptime).
> - Lihat Trafik Interface (Realtime).
> - Start Live Monitor (Background Service).
> - Tampil Notifikasi Persisten (Status Router di Notifikasi Bar).
> - Refresh Data Manual.

### 3. Use Case: Manajemen PPPoE (CRUD)

**Prompt:**

> Buatkan diagram Use Case khusus untuk fitur **"Manajemen PPPoE"**.
> **Aktor:** Administrator.
> **Use Case:**
>
> - Lihat Daftar User (Secrets).
> - Tambah User Baru (Add Secret).
> - Edit Data User (Update Secret).
> - Hapus User (Delete Secret).
> - Lihat User Aktif (Active Connections).
> - Putus Koneksi User (Disconnect/Kick).
> - Filter Status (Online/Offline).

### 4. Use Case: Billing & Logs

**Prompt:**

> Buatkan diagram Use Case khusus untuk fitur **"Billing & Logs"**.
> **Aktor:** Administrator.
> **Use Case:**
>
> - Lihat Status Tagihan Pelanggan (Filter Bulan/Tahun).
> - Tambah Pembayaran (Cash/Transfer).
> - Sinkronisasi Log Router ke Backend (Auto-Sync).
> - Lihat Log Sistem (Filter Warna/Icon).
> - Terima Notifikasi Log Kritis (Local Notification).

---

## B. ACTIVITY DIAGRAM (PER PROSES)

### 1. Activity: Proses Login

**Prompt:**

> Buatkan Activity Diagram untuk **"Proses Login"**.
> **Alur:** Start -> Input IP/User/Pass -> Klik Connect -> Validasi Input Kosong? -> (Jika Ya: Tampil Error) -> (Jika Tidak: Cek Koneksi Socket) -> Koneksi Berhasil? -> (Jika Tidak: Tampil Error Timeout) -> (Jika Ya: Kirim Login API) -> Login Sukses? -> (Jika Tidak: Tampil Error Auth) -> (Jika Ya: Simpan Sesi di SharedPrefs -> Start LiveMonitorService -> Masuk Dashboard) -> End.

### 2. Activity: Proses Live Monitor (Background Service)

**Prompt:**

> Buatkan Activity Diagram untuk **"Proses Live Monitor"**.
> **Alur:** Start Service -> Inisialisasi Notification Channel -> Loop (Tiap 1 Detik) -> Fetch Resource (CPU/Mem) -> Fetch Interface Traffic -> Hitung Rate (Tx/Rx) -> Update Konten Notifikasi (Persistent) -> Cek Stop Signal? -> (Jika Ya: Hapus Notifikasi & Stop Timer) -> (Jika Tidak: Ulangi Loop) -> End.

### 3. Activity: Proses Sinkronisasi Log (LogSyncService)

**Prompt:**

> Buatkan Activity Diagram untuk **"Proses Sinkronisasi Log"**.
> **Alur:** Start Service -> Loop (Tiap 10 Detik) -> Fetch Log dari Router -> Filter Log (PPPoE/Error/Account) -> Ada Log Baru? -> (Jika Tidak: Skip) -> (Jika Ya: Kirim ke Backend API) -> Cek Log Kritis (Connected/Disconnected/Payment)? -> (Jika Ya: Tampil Notifikasi Lokal) -> Update Timestamp Terakhir -> Ulangi Loop -> End.

### 4. Activity: Proses Tambah Pembayaran

**Prompt:**

> Buatkan Activity Diagram untuk **"Proses Tambah Pembayaran"**.
> **Alur:** Start -> Buka Detail User -> Klik "Tambah Pembayaran" -> Input Nominal, Metode, Tanggal -> Klik Simpan -> Kirim ke Backend API -> Sukses? -> (Jika Ya: Tampil Notifikasi Sukses & Refresh List) -> (Jika Tidak: Tampil Error) -> End.

### 5. Activity: Proses Disconnect User Aktif

**Prompt:**

> Buatkan Activity Diagram untuk **"Proses Disconnect User"**.
> **Alur:** Start -> Buka Tab Active -> Pilih User -> Klik Tombol Disconnect (X) -> Kirim Request API (/ppp/active/remove) -> User Terputus di Router -> Refresh List Active -> End.

---

## C. SEQUENCE DIAGRAM (PER API CALL)

### 1. Sequence: Login Flow

**Prompt:**

> Buatkan Sequence Diagram detail untuk **"Login Flow"**.
> **Partisipan:** Admin, LoginScreen, MikrotikService, RouterSessionProvider, LiveMonitorService.
> **Pesan:**
>
> 1. `inputCredentials()`
> 2. `connect(ip, user, pass)`
> 3. `Socket.connect()` (Probe)
> 4. `api_login()` (REST API)
> 5. `return token/session`
> 6. `saveSession()` (Provider)
> 7. `LiveMonitorService.startMonitoring()`
> 8. `navigateToDashboard()`

### 2. Sequence: Live Monitor Update Loop

**Prompt:**

> Buatkan Sequence Diagram detail untuk **"Live Monitor Update Loop"**.
> **Partisipan:** LiveMonitorService, MikrotikService, RouterOS, NotificationManager.
> **Pesan:**
>
> 1. `Timer.tick(1s)`
> 2. `getResource()` -> GET /system/resource
> 3. `return cpu, memory`
> 4. `getTraffic(interfaceId)`
> 5. `GET /interface/{id}` (T1)
> 6. `Wait(1s)`
> 7. `GET /interface/{id}` (T2)
> 8. `calculateRate(T2 - T1)`
> 9. `return tx, rx`
> 10. `showNotification(persistent)`

### 3. Sequence: Log Sync & Notification

**Prompt:**

> Buatkan Sequence Diagram detail untuk **"Log Sync & Notification"**.
> **Partisipan:** LogSyncService, MikrotikService, BackendAPI, NotificationManager.
> **Pesan:**
>
> 1. `Timer.tick(10s)`
> 2. `getLog()` -> GET /log
> 3. `filterLogs(critical)`
> 4. `syncToBackend(logs)` -> POST /api/sync_logs
> 5. `checkLocalNotification()`
> 6. `showNotification(alert)` (Jika ada log kritis)

### 4. Sequence: Add Payment

**Prompt:**

> Buatkan Sequence Diagram detail untuk **"Add Payment"**.
> **Partisipan:** Admin, BillingScreen, ApiService, BackendAPI.
> **Pesan:**
>
> 1. `submitPayment()`
> 2. `ApiService.addPayment()`
> 3. `POST /api/save_payment.php`
> 4. `return success`
> 5. `LogSyncService.testNotification()` (Feedback Lokal)
> 6. `refreshData()`

---

## D. CLASS DIAGRAM (LENGKAP)

**Prompt:**

> Buatkan **Class Diagram** lengkap yang mencakup seluruh struktur aplikasi.
> **Classes:**
>
> 1.  **MikrotikService:** `connect()`, `getTraffic()`, `addSecret()`, `deleteSecret()`, `getLog()`.
> 2.  **ApiService:** `syncUsers()`, `addPayment()`, `getBilling()`.
> 3.  **RouterSessionProvider:** `saveSession()`, `loadSession()`, `routerId`.
> 4.  **MikrotikProvider:** `refreshData()`, `pppSecrets`, `pppSessions`.
> 5.  **LiveMonitorService:** `startMonitoring()`, `_updateNotification()`.
> 6.  **LogSyncService:** `startAutoSync()`, `_syncLogs()`, `_showSystemNotification()`.
> 7.  **Screens:** `LoginScreen`, `DashboardScreen`, `SecretsActiveScreen`, `BillingScreen`, `SystemLogsScreen`.
>     **Hubungan:**
>     - Screens menggunakan Providers (Dependency).
>     - Providers menggunakan Services (Association).
>     - Services berkomunikasi dengan RouterOS/Backend.
