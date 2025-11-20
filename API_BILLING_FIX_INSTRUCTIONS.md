# 🔧 API Billing Documentation

## 📋 Ringkasan

Aplikasi Flutter sudah menggunakan API billing endpoint yang baru dan sudah diperbaiki untuk menangani error dengan baik.

## ✅ Endpoint yang Digunakan

### **Payment Summary Endpoint:**
- **File:** `api/payment_summary_operations.php`
- **Actions:**
  - `summary`: Ringkasan pembayaran per bulan/tahun
  - `detail`: Detail semua pembayaran untuk bulan/tahun tertentu

### **Legacy Endpoints (Deprecated):**
- `get_payment_summary.php` - TIDAK DIGUNAKAN
- `get_all_payments_for_month_year.php` - TIDAK DIGUNAKAN

## ✅ Solusi yang Sudah Diterapkan di Flutter App

### 1. **Type Casting Fix** ✔️
```dart
// Sebelum (Error)
return data['data'] as List<Map<String, dynamic>>;

// Sesudah (Fixed)
final List<dynamic> rawData = data['data'] as List<dynamic>;
final List<Map<String, dynamic>> convertedData = rawData
    .map((item) => Map<String, dynamic>.from(item as Map))
    .toList();
```

### 2. **Timeout Handling** ✔️
```dart
final response = await http.get(
  Uri.parse('$baseUrl/payment_summary_operations.php').replace(queryParameters: {
    'action': 'summary',
    'router_id': routerId,
  }),
  headers: {'Accept': 'application/json'},
).timeout(
  const Duration(seconds: 15),
  onTimeout: () => throw Exception('Koneksi timeout. Silakan coba lagi.'),
);
```

### 3. **Type Safety** ✔️
```dart
final List<dynamic> rawData = data['data'] as List<dynamic>;
final List<Map<String, dynamic>> convertedData = rawData
    .map((item) => Map<String, dynamic>.from(item as Map))
    .toList();
```

### 4. **Better Error Messages** ✔️
```dart
if (e.toString().contains('SocketException')) {
  throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet.');
} else if (e.toString().contains('TimeoutException')) {
  throw Exception('Koneksi timeout. Silakan coba lagi.');
} else if (e.toString().contains('FormatException')) {
  throw Exception('Format data tidak valid. Periksa konfigurasi API.');
}
```

## 📊 Testing API Endpoints

### **Cara Test Manual:**

**1. Via Browser:**
```
http://cmmnetwork.online/api/payment_summary_operations.php?action=summary&router_id=YOUR_ROUTER_ID
```
Harusnya return JSON.

**2. Via cURL:**
```bash
curl "http://cmmnetwork.online/api/payment_summary_operations.php?action=summary&router_id=YOUR_ROUTER_ID"
```

**3. Expected Response:**
```json
{
  "success": true,
  "data": [
    {
      "month": 10,
      "year": 2025,
      "total": 1500000,
      "count": 30
    }
  ]
}
```

## 🔍 API Implementation Details

### **Router ID Helper:**
File `router_id_helper.php` menyediakan fungsi:
- `requireRouterIdFromGet($conn)` - Validasi router_id dari GET parameter
- `requireRouterIdFromBody($conn, $data)` - Validasi router_id dari POST body
- `requireRouterId($conn, $data)` - Validasi fleksibel GET atau POST

### **Security:**
- CORS diaktifkan untuk semua origin
- Prepared statements untuk mencegah SQL injection
- Error handling terpusat dengan JSON response
- Timeout 30 detik untuk mencegah long-running queries

## 📝 Database Schema Required

Pastikan tabel database sudah benar:

```sql
CREATE TABLE IF NOT EXISTS `payments` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `router_id` VARCHAR(255) NOT NULL,
  `username` VARCHAR(255),
  `amount` DECIMAL(10,2) NOT NULL,
  `payment_date` DATE NOT NULL,
  `payment_month` INT NOT NULL,
  `payment_year` INT NOT NULL,
  `method` VARCHAR(50) DEFAULT 'Cash',
  `note` TEXT,
  `created_by` VARCHAR(255),
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
);
```

## ✅ Status Implementasi

| Component | Status | Keterangan |
|-----------|--------|------------|
| API Endpoint | ✅ Complete | payment_summary_operations.php |
| Type Casting | ✅ Fixed | Safe type conversion |
| Error Handling | ✅ Fixed | User-friendly messages |
| Timeout Handler | ✅ Fixed | 15 detik timeout |
| Router ID Validation | ✅ Complete | Centralized helper |
| Database Schema | ✅ Complete | Payments table dengan router_id |

## 📞 Support

Jika ada masalah:
- Periksa error log di Flutter debug console
- Test API endpoint langsung via browser/Postman
- Pastikan `router_id` valid dan ada di database

---

**Last Updated:** 23 November 2025  
**Version:** 2.0


