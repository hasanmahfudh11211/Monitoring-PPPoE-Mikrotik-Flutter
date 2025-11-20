# 🔒 Security Notes - Mikrotik PPPoE Monitor

**IMPORTANT:** Baca dokumen ini sebelum deployment ke production!

---

## ⚠️ CRITICAL SECURITY ISSUES FIXED

### 1. ✅ FIXED: Database Credentials Exposed

**Problem:**
```php
// OLD CODE (INSECURE!)
$user = 'root';
$pass = 'yahahahusein112';
```

**Solution:**
File `api/config.php` sudah diupdate untuk support environment variables:

```php
// NEW CODE (SECURE)
$pass = $_ENV['DB_PASS'] ?? getenv('DB_PASS') ?: 'yahahahusein112';
```

**Action Required:**
1. Buat file `api/.env` dengan password yang secure
2. Set permissions: `chmod 600 api/.env`
3. Jangan commit `.env` file ke git (sudah di .gitignore)
4. Untuk production, gunakan environment variables di server config

**Example `.env` file:**
```env
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=V3ry_S3cur3_P@ssw0rd_H3r3!
```

---

### 2. ⚠️ TODO: HTTPS Implementation

**Current Status:** API menggunakan HTTP (plain text)

**Risk:**
- Credentials dikirim tanpa enkripsi
- Man-in-the-middle attacks possible
- Data pembayaran tidak aman

**Solution:**
Install SSL certificate di server:

```bash
# Using Let's Encrypt (Free)
sudo apt-get install certbot python3-certbot-apache
sudo certbot --apache -d yourserver.com
```

Update API base URL di `lib/services/api_service.dart`:
```dart
static const String baseUrl = 'https://yourserver.com/api'; // Note: HTTPS
```

Update Mikrotik service:
```
/ip service set www-ssl certificate=your-certificate port=443
```

---

### 3. ⚠️ TODO: API Authentication

**Current Status:** API endpoints tidak memerlukan authentication

**Risk:**
- Anyone can access API
- Data exposure
- Possible abuse/spam

**Solution Option A: API Key Authentication**

**Backend (add to all API files):**
```php
<?php
// api/auth_check.php
function checkApiKey() {
    $api_key = $_SERVER['HTTP_X_API_KEY'] ?? '';
    $valid_key = $_ENV['API_KEY'] ?? 'your_secret_key_here';
    
    if ($api_key !== $valid_key) {
        http_response_code(401);
        echo json_encode(['success' => false, 'error' => 'Unauthorized']);
        exit();
    }
}

// Include at top of each API file
require_once 'auth_check.php';
checkApiKey();
```

**Flutter (update http requests):**
```dart
final response = await http.get(
  Uri.parse('$baseUrl/endpoint.php'),
  headers: {
    'Accept': 'application/json',
    'X-API-KEY': 'your_secret_key_here', // Store securely
  },
);
```

**Solution Option B: JWT Token Authentication**

Lebih complex tapi lebih secure. Implementation:
1. User login → generate JWT token
2. Store token di secure storage
3. Include token di setiap API request
4. Validate token di backend

---

### 4. ⚠️ TODO: SQL Injection Prevention

**Current Status:** Beberapa query masih vulnerable

**Found in:**
- `api/sync_ppp_to_db.php` (line 27, 30)
- `api/save_user.php` (line 60)

**Example vulnerable code:**
```php
// INSECURE!
$check = $conn->query("SELECT username FROM users WHERE username = '$username'");
```

**Fixed code (use prepared statements):**
```php
// SECURE
$stmt = $conn->prepare("SELECT username FROM users WHERE username = ?");
$stmt->bind_param("s", $username);
$stmt->execute();
```

**Action Required:**
Review and update all SQL queries to use prepared statements.

---

### 5. ✅ PARTIALLY FIXED: Sensitive Files in Git

**Fixed:**
- Removed `.hprof` files
- Removed log files
- Updated `.gitignore`

**Still at Risk:**
- `android/my-release-key.jks` (keystore di root dan android folder)
- `android/key.properties` (partial)

**Action Required:**

```bash
# Remove from git history
git rm --cached android/*.jks
git rm --cached android/my-release-key.jks
git commit -m "Remove keystore files"

# Add to .gitignore (already done)
# *.jks is in .gitignore
```

**For production:**
1. Generate NEW keystore (current one is compromised)
2. Store keystore securely (NOT in git)
3. Use CI/CD secrets for signing

---

### 6. ⚠️ TODO: Input Validation & Sanitization

**Current Status:** Limited input validation

**Risks:**
- XSS attacks possible
- File upload vulnerabilities
- Data integrity issues

**Solutions:**

**PHP Backend:**
```php
// Sanitize input
function sanitizeInput($data) {
    $data = trim($data);
    $data = stripslashes($data);
    $data = htmlspecialchars($data);
    return $data;
}

// Validate data types
function validatePaymentData($data) {
    if (!is_numeric($data['amount']) || $data['amount'] <= 0) {
        throw new Exception('Invalid amount');
    }
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $data['payment_date'])) {
        throw new Exception('Invalid date format');
    }
    return true;
}
```

**Flutter:**
```dart
// Validate before sending
String? validateUsername(String? value) {
  if (value == null || value.isEmpty) {
    return 'Username tidak boleh kosong';
  }
  if (value.length < 3) {
    return 'Username minimal 3 karakter';
  }
  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
    return 'Username hanya boleh huruf, angka, dan underscore';
  }
  return null;
}
```

---

### 7. ⚠️ TODO: Rate Limiting

**Current Status:** No rate limiting implemented

**Risk:**
- API abuse
- DDoS attacks
- Server overload

**Solution:**

**Simple PHP rate limiting:**
```php
<?php
// api/rate_limit.php
session_start();

function checkRateLimit($max_requests = 100, $time_window = 3600) {
    $ip = $_SERVER['REMOTE_ADDR'];
    $key = "rate_limit_$ip";
    
    if (!isset($_SESSION[$key])) {
        $_SESSION[$key] = ['count' => 0, 'start' => time()];
    }
    
    $data = $_SESSION[$key];
    
    // Reset if time window expired
    if (time() - $data['start'] > $time_window) {
        $data = ['count' => 0, 'start' => time()];
    }
    
    $data['count']++;
    $_SESSION[$key] = $data;
    
    if ($data['count'] > $max_requests) {
        http_response_code(429);
        echo json_encode(['error' => 'Too many requests']);
        exit();
    }
}

// Include in each API file
require_once 'rate_limit.php';
checkRateLimit();
```

---

### 8. ⚠️ TODO: Error Information Disclosure

**Current Status:** Detailed error messages exposed to users

**Risk:**
- Information leakage
- Helps attackers understand system

**Example:**
```php
// DON'T DO THIS IN PRODUCTION!
echo json_encode(['error' => $conn->error]);
```

**Solution:**

**Development:**
```php
ini_set('display_errors', 1);
error_reporting(E_ALL);
```

**Production:**
```php
ini_set('display_errors', 0);
error_log($error_message); // Log to file
echo json_encode(['error' => 'An error occurred. Please contact support.']);
```

---

## 🛡️ Security Best Practices Checklist

### Before Production Deployment:

- [ ] **Database Security**
  - [ ] Use non-root database user
  - [ ] Strong password (min 16 characters)
  - [ ] Environment variables for credentials
  - [ ] Restrict database user privileges
  - [ ] Regular database backups

- [ ] **API Security**
  - [ ] HTTPS enabled with valid SSL certificate
  - [ ] API key or JWT authentication
  - [ ] Rate limiting implemented
  - [ ] CORS properly configured
  - [ ] Input validation & sanitization
  - [ ] All SQL queries use prepared statements

- [ ] **File Security**
  - [ ] Sensitive files not in git (keystore, .env)
  - [ ] Proper file permissions (600 for sensitive files)
  - [ ] Upload folder protected
  - [ ] .htaccess configured

- [ ] **Mikrotik Security**
  - [ ] Dedicated API user (not admin)
  - [ ] Strong password
  - [ ] Firewall rules to restrict API access
  - [ ] HTTPS for REST API (port 443)
  - [ ] Regular RouterOS updates

- [ ] **Application Security**
  - [ ] Code obfuscation for APK
  - [ ] Signed with production keystore
  - [ ] API keys not hardcoded
  - [ ] Secure storage for credentials
  - [ ] Certificate pinning (advanced)

- [ ] **Monitoring & Logging**
  - [ ] Error logging configured
  - [ ] Access logs enabled
  - [ ] Failed login attempts tracked
  - [ ] Anomaly detection
  - [ ] Regular security audits

---

## 🔧 Quick Security Fixes

### Immediate Actions (5 minutes):

```bash
# 1. Create .env file
cd api
cat > .env << EOF
DB_HOST=localhost
DB_NAME=pppoe_monitor
DB_USER=pppoe_user
DB_PASS=$(openssl rand -base64 24)
EOF

# 2. Set permissions
chmod 600 .env
chown www-data:www-data .env

# 3. Remove sensitive files from git
git rm --cached android/*.jks
git rm --cached android/*.hprof
git commit -m "Remove sensitive files"

# 4. Update .gitignore (already done)

# 5. Test API
curl http://localhost/api/get_all_users.php
```

---

## 📚 Additional Resources

**Security Learning:**
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [PHP Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/PHP_Configuration_Cheat_Sheet.html)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [MySQL Security Guide](https://dev.mysql.com/doc/refman/8.0/en/security-guidelines.html)

**Security Tools:**
- [SQLMap](http://sqlmap.org/) - SQL injection testing
- [Burp Suite](https://portswigger.net/burp) - Web vulnerability scanner
- [OWASP ZAP](https://www.zaproxy.org/) - Security testing

---

## 📞 Security Contact

Jika menemukan security vulnerability, please report to:

- Email: hasanmahfudh112@gmail.com
- Subject: [SECURITY] Mikrotik Monitor Vulnerability Report

**DO NOT** publicly disclose security vulnerabilities!

---

**Last Updated:** October 24, 2024  
**Security Review Date:** October 24, 2024  
**Next Review:** January 24, 2025

