# 🔄 Panduan Merge Router ID - Menghapus Duplikasi Data

## 📋 Masalah

Ketika `router_id` berubah (misalnya dari `RB-RouterOS@192.168.99.1:80` ke `03FK-Q7XE` setelah perbaikan bug), sistem menganggapnya sebagai router berbeda, sehingga user yang sama muncul duplikat di database.

**Contoh:**
- **Baris 1**: `router_id = 'RB-RouterOS@192.168.99.1:80'`, `username = 'api@sadam'`
- **Baris 2**: `router_id = '03FK-Q7XE'`, `username = 'api@sadam'` (DUPLIKAT!)

## ✅ Solusi: Merge Router ID

Script `api/merge_router_ids.php` dapat menggabungkan data dari router_id lama ke router_id baru.

---

## 🚀 Cara Menggunakan

### **Metode 1: Via cURL (Terminal/Command Prompt)**

```bash
curl -X POST http://your-server/api/merge_router_ids.php \
  -H "Content-Type: application/json" \
  -d '{
    "old_router_id": "RB-RouterOS@192.168.99.1:80",
    "new_router_id": "03FK-Q7XE",
    "merge_strategy": "newest"
  }'
```

### **Metode 2: Via Postman/HTTP Client**

1. **Method**: `POST`
2. **URL**: `http://your-server/api/merge_router_ids.php`
3. **Headers**:
   - `Content-Type: application/json`
4. **Body** (JSON):
```json
{
  "old_router_id": "RB-RouterOS@192.168.99.1:80",
  "new_router_id": "03FK-Q7XE",
  "merge_strategy": "newest"
}
```

### **Metode 3: Via PHP Script**

Buat file `test_merge.php` di folder `api/`:
```php
<?php
$data = [
    'old_router_id' => 'RB-RouterOS@192.168.99.1:80',
    'new_router_id' => '03FK-Q7XE',
    'merge_strategy' => 'newest'
];

$ch = curl_init('http://localhost/api/merge_router_ids.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$response = curl_exec($ch);
curl_close($ch);

echo $response;
?>
```

---

## 📝 Parameter

| Parameter | Type | Wajib? | Deskripsi |
|-----------|------|--------|-----------|
| `old_router_id` | string | ✅ Ya | Router ID lama yang ingin diganti |
| `new_router_id` | string | ✅ Ya | Router ID baru (target) |
| `merge_strategy` | string | ❌ Tidak | Strategi merge (default: `newest`) |

### **Merge Strategy Options:**

1. **`newest`** (Default) - **Rekomendasi**
   - Menghapus data dengan router_id lama
   - Menyimpan data dengan router_id baru
   - Cocok jika data baru lebih lengkap

2. **`oldest`**
   - Menghapus data dengan router_id baru
   - Menyimpan data dengan router_id lama
   - Cocok jika data lama lebih penting

3. **`complete`**
   - Merge field: ambil data non-kosong dari keduanya
   - Hapus duplikat setelah merge
   - Cocok jika ingin menggabungkan semua data

---

## 📊 Response

### **Success Response:**
```json
{
  "success": true,
  "old_router_id": "RB-RouterOS@192.168.99.1:80",
  "new_router_id": "03FK-Q7XE",
  "merge_strategy": "newest",
  "stats": {
    "users_merged": 150,
    "users_deleted": 2,
    "duplicates_found": 2,
    "payments_updated": 45,
    "odp_updated": 0
  }
}
```

### **Error Response:**
```json
{
  "success": false,
  "error": "old_router_id dan new_router_id tidak boleh sama",
  "timestamp": "2025-11-01 14:00:00"
}
```

---

## 🔍 Contoh Use Cases

### **Case 1: Merge setelah bug fix**
```json
{
  "old_router_id": "RB-RouterOS@192.168.99.1:80",
  "new_router_id": "03FK-Q7XE",
  "merge_strategy": "newest"
}
```
**Hasil**: Semua data dengan router_id lama akan digabungkan ke router_id baru (serial-number).

### **Case 2: Cleanup data setelah migrasi**
```json
{
  "old_router_id": "DEFAULT-ROUTER",
  "new_router_id": "03FK-Q7XE",
  "merge_strategy": "newest"
}
```
**Hasil**: Data placeholder digabungkan ke router_id yang benar.

---

## ⚠️ Peringatan

1. **Backup Database Dulu!**
   ```bash
   mysqldump -u root -p pppoe_monitor > backup_before_merge.sql
   ```

2. **Test di Environment Development**
   - Jangan langsung merge di production
   - Test dulu dengan sample data

3. **Cek Duplikat Sebelum Merge**
   ```sql
   SELECT username, COUNT(*) as count
   FROM users
   WHERE router_id IN ('RB-RouterOS@192.168.99.1:80', '03FK-Q7XE')
   GROUP BY username
   HAVING count > 1;
   ```

4. **Transaction Safe**
   - Script menggunakan database transaction
   - Jika ada error, semua perubahan di-rollback
   - Database tetap konsisten

---

## 🛠️ Troubleshooting

### **Error: "old_router_id dan new_router_id tidak boleh sama"**
- Pastikan kedua router_id berbeda
- Cek apakah ada whitespace

### **Error: "Database connection failed"**
- Cek `api/config.php`
- Pastikan database credentials benar

### **Tidak ada data yang di-merge**
- Cek apakah router_id lama benar-benar ada di database
- Jalankan query untuk verifikasi:
  ```sql
  SELECT COUNT(*) FROM users WHERE router_id = 'RB-RouterOS@192.168.99.1:80';
  ```

---

## 📚 Related Files

- `api/merge_router_ids.php` - Script merge
- `api/backfill_router_id.php` - Script backfill untuk data lama
- `api/cleanup_duplicates.php` - Script cleanup duplikat umum
- `migrations/001_add_router_id.sql` - Migration untuk menambah router_id

---

## ✅ Checklist Sebelum Merge

- [ ] Backup database sudah dibuat
- [ ] Router ID lama dan baru sudah dikonfirmasi
- [ ] Test di environment development
- [ ] Cek duplikat dengan query SQL
- [ ] Pilih merge strategy yang tepat
- [ ] Verifikasi hasil setelah merge

---

**Generated**: November 2025  
**Author**: System  
**Version**: 1.0





















