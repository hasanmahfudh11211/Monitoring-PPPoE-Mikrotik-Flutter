# 🚀 Cara Cepat Fix Duplikasi Data - Step by Step

## 📍 **Step 1: Cek Duplikat di Database**

Buka browser, akses:
```
http://your-server/api/check_duplicates.php
```

Atau langsung jalankan query di phpMyAdmin:
```sql
SELECT username, 
       GROUP_CONCAT(DISTINCT router_id SEPARATOR ' | ') as router_ids,
       COUNT(*) as count
FROM users
GROUP BY username
HAVING count > 1;
```

**Contoh hasil:**
```json
{
  "duplicate_users": [
    {
      "username": "api@sadam",
      "router_ids": "RB-RouterOS@192.168.99.1:80 | 03FK-Q7XE",
      "count": 2
    }
  ]
}
```

---

## 🔧 **Step 2: Fix Duplikat - PILIH SATU CARA**

### **CARA A: Via Script Otomatis (AMAN + RECOMMENDED)**

Buka browser atau gunakan cURL:

**Option 1: Via Browser (Postman/Thunder Client extension)**
```
Method: POST
URL: http://your-server/api/merge_router_ids.php
Headers:
  Content-Type: application/json

Body (JSON):
{
  "old_router_id": "RB-RouterOS@192.168.99.1:80",
  "new_router_id": "03FK-Q7XE",
  "merge_strategy": "newest"
}
```

**Option 2: Via cURL (Terminal/Command Prompt)**
```bash
curl -X POST http://your-server/api/merge_router_ids.php \
  -H "Content-Type: application/json" \
  -d "{\"old_router_id\":\"RB-RouterOS@192.168.99.1:80\",\"new_router_id\":\"03FK-Q7XE\",\"merge_strategy\":\"newest\"}"
```

**Option 3: Via Postman/Thunder Client**

1. Install Thunder Client extension di VS Code (atau gunakan Postman)
2. Buat POST request baru
3. URL: `http://your-server/api/merge_router_ids.php`
4. Headers: `Content-Type: application/json`
5. Body (raw JSON):
```json
{
  "old_router_id": "RB-RouterOS@192.168.99.1:80",
  "new_router_id": "03FK-Q7XE",
  "merge_strategy": "newest"
}
```
6. Click Send

---

### **CARA B: Via SQL Manual (LEBIH CEPAT, tapi hati-hati!)**

Buka phpMyAdmin, jalankan query berikut **satu per satu**:

```sql
-- 1. Cek dulu berapa duplikat yang akan dihapus
SELECT COUNT(*) as akan_dihapus
FROM users u1
INNER JOIN users u2 ON u1.username = u2.username
WHERE u1.router_id = 'RB-RouterOS@192.168.99.1:80' 
AND u2.router_id = '03FK-Q7XE';

-- 2. Hapus duplikat (yang lama)
DELETE u1 FROM users u1
INNER JOIN users u2 ON u1.username = u2.username
WHERE u1.router_id = 'RB-RouterOS@192.168.99.1:80'
AND u2.router_id = '03FK-Q7XE';

-- 3. Update sisa data ke router_id baru
UPDATE users 
SET router_id = '03FK-Q7XE', updated_at = NOW()
WHERE router_id = 'RB-RouterOS@192.168.99.1:80';

-- 4. Update payments
UPDATE payments p
INNER JOIN users u ON p.user_id = u.id
SET p.router_id = u.router_id
WHERE p.router_id != u.router_id;

-- 5. Update ODP
UPDATE odp
SET router_id = '03FK-Q7XE'
WHERE router_id = 'RB-RouterOS@192.168.99.1:80';
```

---

## ✅ **Step 3: Verifikasi Hasil**

Jalankan query untuk cek:
```sql
-- Cek apakah masih ada duplikat
SELECT username, COUNT(*) as count
FROM users
GROUP BY username
HAVING count > 1;

-- Harusnya hasilnya KOSONG (0 rows)

-- Cek data untuk router baru
SELECT COUNT(*) as total_users, router_id
FROM users
WHERE router_id = '03FK-Q7XE'
GROUP BY router_id;

-- Pastikan total_users lebih besar dari 0
```

Atau akses lagi:
```
http://your-server/api/check_duplicates.php
```

Harusnya `"duplicate_usernames": 0`

---

## ⚠️ **PENTING! Backup Dulu!**

Sebelum merge, **WAJIB backup database**:

```bash
# Via command line
mysqldump -u root -p pppoe_monitor > backup_$(date +%Y%m%d_%H%M%S).sql

# Atau via phpMyAdmin
# klik "Export" → pilih database pppoe_monitor → Go
```

---

## 🎯 **FAQ**

**Q: Router ID mana yang harus jadi `old` dan `new`?**
A: Yang LAMA = format `RB-xxx@ip:port`, yang BARU = format serial-number seperti `03FK-Q7XE`

**Q: Merge strategy mana yang dipakai?**
A: Pakai `"newest"` (default) - keep data terbaru, hapus data lama

**Q: Apa yang terjadi kalau salah jalan?**
A: Script pakai transaction, kalau error otomatis rollback. Tapi tetap backup dulu!

**Q: Bisa pakai cara lain selain script PHP?**
A: Bisa! Ada 2 cara:
- **Script PHP** (aman, otomatis) ← **REKOMENDASI**
- **SQL Manual** (cepat, tapi harus hati-hati)

---

## 📞 **Need Help?**

Jika masih bingung:
1. Baca `MERGE_ROUTER_ID_GUIDE.md` untuk detail lengkap
2. Cek `api/merge_router_ids.php` untuk source code
3. Test di development environment dulu

---

**Quick Command Summary:**

```bash
# 1. Backup
mysqldump -u root -p pppoe_monitor > backup.sql

# 2. Check duplikat
curl http://your-server/api/check_duplicates.php

# 3. Fix duplikat
curl -X POST http://your-server/api/merge_router_ids.php \
  -H "Content-Type: application/json" \
  -d '{"old_router_id":"RB-RouterOS@192.168.99.1:80","new_router_id":"03FK-Q7XE","merge_strategy":"newest"}'

# 4. Verify
curl http://your-server/api/check_duplicates.php
```

**DONE! 🎉**





















