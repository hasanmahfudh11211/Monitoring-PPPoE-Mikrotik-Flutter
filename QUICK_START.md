# ⚡ Quick Start Guide - Mikrotik PPPoE Monitor

Panduan cepat untuk mulai menggunakan aplikasi dalam 15 menit!

---

## 🎯 Prerequisites

✅ Mikrotik Router (RouterOS 7.9+)  
✅ Web Server dengan PHP & MySQL  
✅ Android Device untuk testing  

---

## 🚀 Setup dalam 5 Langkah

### 1️⃣ Setup Database (3 menit)

```bash
# Login ke MySQL
mysql -u root -p

# Import schema
mysql -u root -p < database_schema.sql

# Create user
mysql -u root -p -e "CREATE USER 'pppoe_user'@'localhost' IDENTIFIED BY 'password123'; GRANT ALL PRIVILEGES ON pppoe_monitor.* TO 'pppoe_user'@'localhost'; FLUSH PRIVILEGES;"
```

✅ **Test:** 
```sql
USE pppoe_monitor;
SHOW TABLES;
-- Harus muncul 4 tables
```

---

### 2️⃣ Configure Backend (2 menit)

```bash
# Navigate to api folder
cd api

# Create .env file
cat > .env << 'EOF'
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=password123
EOF

# Set permissions
chmod 600 .env
```

✅ **Test:**
```bash
curl http://localhost/api/get_all_users.php
# Expected: {"success":true,"data":[]}
```

---

### 3️⃣ Configure Mikrotik (3 menit)

```bash
# Login via SSH/Winbox/WebFig
ssh admin@your-router-ip

# Enable REST API
/ip service set www port=80 disabled=no

# Create API user (RECOMMENDED)
/user add name=api_user password=api123456 group=full
```

✅ **Test:**
```bash
curl -u api_user:api123456 http://your-router-ip/rest/system/identity
# Expected: {"name":"YourRouter"}
```

---

### 4️⃣ Build Flutter App (5 menit)

```bash
# Update API URL (jika bukan localhost)
# Edit: lib/services/api_service.dart
# Line 5: static const String baseUrl = 'http://YOUR_SERVER/api';

# Clean & build
flutter clean
flutter pub get
flutter build apk --release

# APK ready di: build/app/outputs/flutter-apk/app-release.apk
```

✅ **Test:** Install APK ke Android device

---

### 5️⃣ First Login (2 menit)

1. Buka aplikasi
2. Masukkan credentials:
   - **IP:** IP Mikrotik Anda
   - **Port:** 80 (atau port yang Anda set)
   - **Username:** api_user (atau admin)
   - **Password:** api123456 (atau password Anda)
3. Klik **Login**

✅ **Success!** Dashboard akan muncul dengan data dari Mikrotik

---

## 📱 Testing Features

### Test 1: View Active Users
1. Dashboard → lihat jumlah user online/offline
2. Tap "User PPP" → lihat daftar user

### Test 2: Add User
1. Tap tombol "+" 
2. Isi form:
   - Username: `testuser`
   - Password: `testpass`
   - Profile: Pilih dari dropdown
3. Save
4. Check di Mikrotik: `/ppp secret print`

### Test 3: Add Payment
1. Menu → Billing
2. Pilih user
3. Tap "Tambah Pembayaran"
4. Isi nominal & tanggal
5. Save

### Test 4: View Reports
1. Menu → Ringkasan Pembayaran
2. Lihat total per bulan
3. Tap bulan → lihat detail
4. Export ke Excel/PDF

---

## 🎨 UI Tour

```
┌─────────────────────────┐
│      DASHBOARD          │  ← Main screen
│  📊 Stats & Graphs      │
│  👥 Online: 10          │
│  💤 Offline: 5          │
└─────────────────────────┘
         ↓
┌─────────────────────────┐
│   ☰ Menu                │
├─────────────────────────┤
│ 🏠 Dashboard            │
│ 👥 User PPP             │  ← Manage users
│ 📊 System Resource      │  ← Monitor router
│ 📈 Traffic              │  ← View bandwidth
│ 📝 Log                  │  ← System logs
│ 💰 Billing              │  ← Payment tracking
│ 📍 ODP                  │  ← Location mgmt
│ ⚙️  Settings            │
└─────────────────────────┘
```

---

## 🔧 Common Issues & Quick Fixes

### ❌ "Koneksi timeout"

**Cause:** Mikrotik tidak terjangkau

**Fix:**
```bash
# Check Mikrotik can be reached
ping your-mikrotik-ip

# Check REST API service
ssh admin@mikrotik
/ip service print
# www atau www-ssl harus enabled
```

---

### ❌ "Username atau password salah"

**Cause:** Credentials salah atau user tidak ada

**Fix:**
```bash
# Verify user exists
/user print

# Reset password
/user set admin password=newpassword

# Or create new user
/user add name=api_user password=api123 group=full
```

---

### ❌ "Database connection failed"

**Cause:** Database credentials salah

**Fix:**
```bash
# Test MySQL connection
mysql -u pppoe_user -p pppoe_monitor

# If fails, recreate user
mysql -u root -p
> DROP USER 'pppoe_user'@'localhost';
> CREATE USER 'pppoe_user'@'localhost' IDENTIFIED BY 'password123';
> GRANT ALL PRIVILEGES ON pppoe_monitor.* TO 'pppoe_user'@'localhost';
> FLUSH PRIVILEGES;

# Update api/.env with correct password
```

---

### ❌ "API mengembalikan HTML"

**Cause:** Server redirect atau error

**Fix:**
```bash
# Test API directly in browser
http://your-server/api/get_all_users.php

# Should show JSON, not HTML
# If shows HTML, check:
# - Apache/Nginx config
# - PHP errors (check error_log)
# - .htaccess rules
```

---

## 🎓 Next Steps

### Setelah Basic Setup Works:

1. **Security** 🔒
   - [ ] Setup HTTPS
   - [ ] Change default passwords
   - [ ] Implement API authentication
   - [ ] Read: `SECURITY_NOTES.md`

2. **Production Deployment** 🚀
   - [ ] Setup on production server
   - [ ] Configure backup strategy
   - [ ] Setup monitoring
   - [ ] Read: `DEPLOYMENT_GUIDE.md`

3. **Customization** 🎨
   - [ ] Customize branding
   - [ ] Add custom profiles
   - [ ] Configure ODP locations
   - [ ] Setup payment methods

4. **Advanced Features** ⚡
   - [ ] Auto-sync with Mikrotik
   - [ ] WhatsApp notifications
   - [ ] Email reports
   - [ ] Multi-router support

---

## 📚 Documentation Index

| Document | Purpose | When to Read |
|----------|---------|--------------|
| `README.md` | Overview & features | ✅ Awal |
| `QUICK_START.md` | Quick setup (this file) | ✅ Untuk mulai cepat |
| `DEPLOYMENT_GUIDE.md` | Production deployment | ⚠️ Sebelum production |
| `SECURITY_NOTES.md` | Security issues & fixes | 🔒 Sebelum production |
| `PERBAIKAN_SUMMARY.md` | What's been fixed | ℹ️ Reference |
| `database_schema.sql` | Database structure | 💾 Setup database |

---

## 💡 Tips & Tricks

### Tip 1: Save Connections
App bisa save multiple router connections. Berguna kalau manage banyak router!

### Tip 2: Dark Mode
Settings → Toggle Dark Mode untuk tampilan lebih nyaman di malam hari

### Tip 3: Export Data
Semua data bisa di-export ke Excel atau PDF untuk reporting

### Tip 4: WhatsApp Integration
Tap nomor WA di detail user → langsung buka WhatsApp

### Tip 5: Google Maps
Tap lokasi → langsung buka Google Maps untuk navigasi

---

## 🐛 Debug Mode

Jika ada masalah, aktifkan debug mode:

**Backend:**
```php
// api/config.php (add at top)
ini_set('display_errors', 1);
error_reporting(E_ALL);
```

**Flutter:**
```bash
# Run in debug mode
flutter run --debug

# View logs
adb logcat | grep Flutter
```

---

## 📞 Need Help?

**Check Documentation:**
1. `README.md` - Features & overview
2. `DEPLOYMENT_GUIDE.md` - Detailed setup
3. `SECURITY_NOTES.md` - Security issues

**Still Stuck?**
- Email: hasanmahfudh112@gmail.com
- Instagram: [@hasan.mhfdz](https://www.instagram.com/hasan.mhfdz)

**Before Asking:**
- ✅ Check documentation
- ✅ Test API with curl
- ✅ Check Mikrotik logs
- ✅ Check PHP error logs
- ✅ Verify database connection

---

## ✅ Checklist: Ready to Go?

**Before You Start:**
- [ ] Mikrotik RouterOS 7.9+ installed
- [ ] Web server with PHP & MySQL ready
- [ ] Android device for testing
- [ ] Basic networking knowledge

**After Setup:**
- [ ] Database imported successfully
- [ ] API endpoints responding
- [ ] Mikrotik REST API enabled
- [ ] App installed & can login
- [ ] Can add/edit users
- [ ] Can track payments

**If All Checked:** 🎉 **You're ready to go!**

---

## 🌟 What's Next?

Setelah basic setup berhasil:

1. **Explore Features** - Coba semua menu & fitur
2. **Add Real Data** - Input user & payment real
3. **Customize** - Sesuaikan dengan kebutuhan
4. **Secure** - Implement security measures
5. **Deploy** - Production deployment
6. **Scale** - Multi-router, notifications, etc.

---

**Happy Monitoring! 🚀**

*Generated: October 24, 2024*  
*Version: 1.0*

