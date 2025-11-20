import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:async';

class MikrotikService {
  String? ip;
  String? port;
  String? username;
  String? password;
  bool enableLogging;

  MikrotikService({
    this.ip,
    this.port,
    this.username,
    this.password,
    this.enableLogging = false,
  });

  // Automatically detect protocol based on port
  // Port 443 = HTTPS, others = HTTP
  String get _protocol {
    final portNum = int.tryParse(port ?? '');
    return (portNum == 443) ? 'https' : 'http';
  }

  String get baseUrl => '$_protocol://$ip:$port/rest';

  Map<String, String> get _headers {
    if (username == null || password == null || username!.isEmpty) {
      throw Exception('Username dan password harus diisi');
    }
    final credentials = '$username:$password';
    final encoded = base64Encode(utf8.encode(credentials));
    // Untuk GET request, kita tidak perlu Content-Type
    // API client biasanya tidak mengirim Content-Type untuk GET
    return {
      'Authorization': 'Basic $encoded',
      'Accept': 'application/json',
    };
  }

  // Cek konektivitas TCP ke IP:port sebelum melakukan HTTP request
  Future<void> _probeConnectivity() async {
    final host = ip;
    final p = int.tryParse(port ?? '');
    if (host == null || host.isEmpty || p == null)
      return; // biarkan HTTP yang memvalidasi
    try {
      final socket =
          await Socket.connect(host, p, timeout: const Duration(seconds: 3));
      await socket.close();
    } on SocketException {
      final protocol = _protocol;
      throw Exception('Tidak dapat terhubung ke $host:$p (TCP)\n\n'
          'Periksa bahwa layanan Web di router aktif:\n'
          '• ${protocol == 'https' ? 'www-ssl (Port 443) untuk HTTPS' : 'www (Port 80) untuk HTTP'}\n'
          '• Pastikan port dapat diakses dari perangkat Anda');
    }
  }

  String _formatErrorMessage(String message) {
    // Remove technical details and format for user display
    message = message.replaceAll('Exception: ', '');
    message = message.replaceAll('ClientException with ', '');
    message = message.replaceAll('SocketException: ', '');

    // Clean up specific error messages
    if (message.contains('Connection refused')) {
      return 'Koneksi ke router gagal karena:\n\n'
          '• Port ${port ?? ""} tidak dapat diakses\n'
          '• API service Mikrotik mungkin tidak aktif\n'
          '• Firewall mungkin memblokir koneksi\n\n'
          'Solusi:\n'
          '1. Periksa apakah port yang dimasukkan benar\n'
          '2. Pastikan service API Mikrotik sudah diaktifkan\n'
          '3. Periksa pengaturan firewall router';
    }

    return message;
  }

  void _logBlock(String title, Map<String, String> rows) {
    if (!enableLogging) return;
    final border = '=' * (12 + title.length);
    print('[MKT] $border');
    print('[MKT] >>> $title');
    rows.forEach((k, v) => print('[MKT] • $k: $v'));
    print('[MKT] $border');
  }

  Future<Map<String, dynamic>> getLicense() async {
    try {
      final uri = Uri.parse('$baseUrl/system/license');
      _logBlock('License Request', {
        'URL': uri.toString(),
        'User': username ?? '-',
      });
      await _probeConnectivity();
      final response = await http
          .get(
            uri,
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      _logBlock('License Response', {
        'Status': '${response.statusCode}',
        'Body': response.body,
      });

      if (response.statusCode == 200) {
        try {
          final body = response.body.trim();
          if (body.isEmpty) {
            throw Exception('Response body kosong dari router');
          }
          final decoded = jsonDecode(body) as Map<String, dynamic>;

          // Beberapa perangkat/versi tidak menampilkan serial-number di license.
          // Gunakan 'serial-number' jika ada; jika tidak, gunakan 'software-id' (unik per instalasi/CHR).
          if (!decoded.containsKey('serial-number') &&
              decoded['software-id'] == null) {
            print(
                'DEBUG License: serial-number & software-id tidak ditemukan di response');
            print(
                'DEBUG License: Keys yang tersedia = ${decoded.keys.toList()}');
            throw Exception(
                'Identitas license tidak ditemukan di response router');
          }

          return decoded;
        } catch (e) {
          if (e is Exception && e.toString().contains('serial-number')) {
            rethrow;
          }
          throw Exception('Gagal memparse license response\n\n'
              'Response: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}\n\n'
              'Error: $e');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Akses ditolak saat mengambil license\n\n'
            'Pastikan user memiliki akses ke system/license');
      } else {
        throw Exception(
            'Gagal mengambil license: Status ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error mengambil license: $e');
    }
  }

  // Mendapatkan identitas unik router
  // Kebijakan: gunakan serial-number dari system/license sebagai routerId utama.
  // Jika tidak tersedia, fallback ke software-id, lalu system/identity.name@ip:port.
  Future<String> getRouterSerialOrId() async {
    // 1) Ambil dari system/license (prioritas: serial-number > software-id)
    try {
      final lic = await getLicense();
      // Prioritas 1: serial-number (lebih unik, dari hardware fisik)
      final serialNumber = lic['serial-number']?.toString();
      if (serialNumber != null && serialNumber.isNotEmpty) return serialNumber;
      // Prioritas 2: software-id (untuk CHR/virtual installation)
      final softwareId = lic['software-id']?.toString();
      if (softwareId != null && softwareId.isNotEmpty) return softwareId;
    } catch (_) {
      // abaikan, lanjut fallback berikutnya
    }

    // 2) Fallback terakhir: gunakan system/identity.name + ip:port
    try {
      final identity = await getIdentity();
      final name = identity['name']?.toString() ?? 'UNKNOWN';
      final addr = '$ip:$port';
      return 'RB-$name@$addr';
    } catch (_) {
      // Jika semuanya gagal, kembalikan IP:PORT agar tetap bisa lanjut (walau kurang ideal)
      return '$ip:$port';
    }
  }

  Future<Map<String, dynamic>> getIdentity() async {
    try {
      final uri = Uri.parse('$baseUrl/system/identity');
      _logBlock('Login Request', {
        'URL': uri.toString(),
        'User': username ?? '-',
        'PasswordLen': '${password?.length ?? 0}',
      });
      await _probeConnectivity();
      final response = await http
          .get(
        uri,
        headers: _headers,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Koneksi timeout (20 detik)\n\n'
              'Kemungkinan penyebab:\n'
              '• Router tidak menyala\n'
              '• IP Address salah\n'
              '• Jaringan tidak stabil\n\n'
              'Solusi:\n'
              '1. Periksa router dan koneksi jaringan\n'
              '2. Pastikan IP benar: ${ip ?? ""}\n'
              '3. Coba hubungkan kembali');
        },
      );

      _logBlock('Login Response', {
        'Status': '${response.statusCode}',
        'Body': response.body,
      });

      if (response.statusCode == 200) {
        try {
          final body = response.body.trim();
          if (body.isEmpty) {
            throw Exception('Response body kosong dari router');
          }
          return jsonDecode(body) as Map<String, dynamic>;
        } catch (e) {
          throw Exception('Gagal memparse response dari router\n\n'
              'Response: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}\n\n'
              'Error: $e');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Login Gagal\n\n'
            'Username atau password salah\n\n'
            'Solusi:\n'
            '1. Periksa kembali username\n'
            '2. Periksa kembali password\n'
            '3. Pastikan huruf besar/kecil sudah benar');
      } else if (response.statusCode == 404) {
        throw Exception('Router Tidak Ditemukan\n\n'
            'Kemungkinan penyebab:\n'
            '• IP Address salah\n'
            '• Port salah\n'
            '• Router tidak terjangkau\n\n'
            'Detail:\n'
            '• IP: ${ip ?? ""}\n'
            '• Port: ${port ?? ""}\n\n'
            'Solusi:\n'
            '1. Periksa IP Address router\n'
            '2. Periksa nomor port\n'
            '3. Pastikan router dan perangkat dalam jaringan yang sama');
      } else {
        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('cannot resolve')) {
          throw Exception('IP Address Tidak Valid\n\n'
              'IP Address yang dimasukkan (${ip ?? ""}) tidak dapat ditemukan\n\n'
              'Solusi:\n'
              '1. Periksa IP Address router\n'
              '2. Pastikan format IP Address benar\n'
              '3. Pastikan router dan perangkat dalam jaringan yang sama');
        } else if (errorBody.contains('connection refused')) {
          throw Exception('Koneksi Ditolak\n\n'
              'Router menolak koneksi pada port ${port ?? ""}\n\n'
              'Kemungkinan penyebab:\n'
              '• Port yang dimasukkan salah\n'
              '• API service Mikrotik tidak aktif\n'
              '• Firewall memblokir koneksi\n\n'
              'Solusi:\n'
              '1. Periksa nomor port\n'
              '2. Aktifkan API service di router\n'
              '3. Periksa pengaturan firewall');
        } else if (errorBody.contains('timeout')) {
          throw Exception('Koneksi Timeout\n\n'
              'Router tidak merespon dalam waktu yang ditentukan\n\n'
              'Kemungkinan penyebab:\n'
              '• Router tidak menyala\n'
              '• Jaringan tidak stabil\n'
              '• Firewall memblokir koneksi\n\n'
              'Solusi:\n'
              '1. Periksa kondisi router\n'
              '2. Periksa koneksi jaringan\n'
              '3. Coba restart router');
        } else {
          throw Exception('Gagal Terhubung ke Router\n\n'
              'Detail error:\n'
              '${_formatErrorMessage(response.body)}\n\n'
              'Solusi:\n'
              '1. Periksa semua pengaturan koneksi\n'
              '2. Pastikan router menyala dan terhubung\n'
              '3. Coba restart aplikasi');
        }
      }
    } catch (e) {
      if (e is Exception) {
        final message = e.toString();
        if (message.contains('SocketException') ||
            message.contains('Connection refused')) {
          throw Exception('Koneksi Gagal\n\n'
              'Tidak dapat terhubung ke router pada:\n'
              '• IP: ${ip ?? ""}\n'
              '• Port: ${port ?? ""}\n\n'
              'Kemungkinan penyebab:\n'
              '• Router tidak menyala\n'
              '• IP Address atau Port salah\n'
              '• API service tidak aktif\n'
              '• Firewall memblokir koneksi\n\n'
              'Solusi:\n'
              '1. Periksa apakah router menyala\n'
              '2. Pastikan IP dan Port benar\n'
              '3. Aktifkan API service di router\n'
              '4. Periksa pengaturan firewall');
        } else if (message.contains('HandshakeException') ||
            message.contains('CertificateException')) {
          final protocol = _protocol;
          throw Exception('Koneksi Tidak Aman\n\n'
              'Terjadi masalah keamanan koneksi\n\n'
              'Kemungkinan penyebab:\n'
              '• Sertifikat SSL tidak valid atau self-signed\n'
              '• Port yang dimasukkan salah\n'
              '• Service www-ssl tidak aktif di router\n\n'
              'Detail:\n'
              '• Protokol: ${protocol.toUpperCase()}\n'
              '• Port: ${port ?? ""}\n\n'
              'Solusi:\n'
              '1. Aktifkan service www-ssl di router (Port 443)\n'
              '2. Pastikan sertifikat SSL sudah dikonfigurasi\n'
              '3. Jika menggunakan self-signed certificate, pastikan Anda mempercayainya\n'
              '4. Atau gunakan HTTP dengan port 80 jika HTTPS tidak diperlukan');
        }
        throw Exception(_formatErrorMessage(message));
      }
      throw Exception('Error Tidak Dikenal\n\n'
          'Terjadi kesalahan yang tidak terduga\n\n'
          'Detail:\n'
          '${_formatErrorMessage(e.toString())}\n\n'
          'Solusi:\n'
          '1. Coba login kembali\n'
          '2. Periksa semua pengaturan\n'
          '3. Restart aplikasi jika masih bermasalah');
    }
  }

  Future<Map<String, dynamic>> getResource() async {
    final response = await http.get(
      Uri.parse('$baseUrl/system/resource'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch resource: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPPPActive() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ppp/active'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch PPP active: ${response.body}');
    }
  }

  Future<void> disconnectSession(String sessionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ppp/active/remove'),
      headers: _headers,
      body: jsonEncode({
        'session-id': sessionId,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to disconnect session: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPPPSecret() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ppp/secret'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch PPP secret: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getLog() async {
    final response = await http.get(
      Uri.parse('$baseUrl/log'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch log: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getInterface() async {
    final response = await http.get(
      Uri.parse('$baseUrl/interface'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch interface: ${response.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getPPPProfile() async {
    final response = await http.get(
      Uri.parse('$baseUrl/ppp/profile'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to fetch PPP profile: ${response.body}');
    }
  }

  Future<void> addPPPSecret(Map<String, String> data) async {
    if (data['name'] == null || data['name']!.isEmpty) {
      throw Exception('Username tidak boleh kosong');
    }
    if (data['password'] == null || data['password']!.isEmpty) {
      throw Exception('Password tidak boleh kosong');
    }
    if (data['profile'] == null || data['profile']!.isEmpty) {
      throw Exception('Profile harus dipilih');
    }

    // Check for existing username
    final existingSecrets = await getPPPSecret();
    final usernameExists = existingSecrets.any((secret) =>
        secret['name']?.toString().toLowerCase() ==
        data['name']?.toLowerCase());

    if (usernameExists) {
      throw Exception(
          'Username "${data['name']}" sudah digunakan. Silakan gunakan username lain.');
    }

    final url = Uri.parse('$baseUrl/ppp/secret/add');
    final requestBody = {
      'name': data['name'],
      'password': data['password'],
      'profile': data['profile'],
      'service': data['service'] ?? 'pppoe',
      'disabled': 'no'
    };

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorBody = response.body;
        if (errorBody.contains('already have')) {
          throw Exception('Username sudah digunakan');
        } else if (errorBody.contains('invalid profile')) {
          throw Exception('Profile tidak valid');
        } else {
          throw Exception('Gagal menambahkan user: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> updatePPPSecret(String name, Map<String, String> data) async {
    if (data['name'] != null && data['name']!.isEmpty) {
      throw Exception('Username tidak boleh kosong');
    }
    if (data['password'] != null && data['password']!.isEmpty) {
      throw Exception('Password tidak boleh kosong');
    }
    if (data['profile'] != null && data['profile']!.isEmpty) {
      throw Exception('Profile harus dipilih');
    }

    // Check if username is being changed and if it already exists
    if (data['name'] != null && data['name'] != name) {
      final existingSecrets = await getPPPSecret();
      final usernameExists = existingSecrets.any((secret) =>
          secret['name']?.toString().toLowerCase() ==
          data['name']?.toLowerCase());

      if (usernameExists) {
        throw Exception(
            'Username "${data['name']}" sudah digunakan. Silakan gunakan username lain.');
      }
    }

    // Get the secret's .id first
    final secrets = await getPPPSecret();
    final secret = secrets.firstWhere(
      (s) => s['name'] == name,
      orElse: () => throw Exception('User tidak ditemukan'),
    );

    final id = secret['.id'];
    if (id == null) throw Exception('User ID tidak ditemukan');

    final url = Uri.parse('$baseUrl/ppp/secret/set');
    final requestBody = {
      '.id': id,
      'name': data['name'] ?? name,
      'password': data['password'] ?? secret['password'],
      'profile': data['profile'] ?? secret['profile'],
      'service': 'pppoe',
      'disabled': 'no'
    };

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('invalid profile')) {
          throw Exception('Profile tidak valid');
        } else if (errorBody.contains('no such item')) {
          throw Exception('User tidak ditemukan');
        } else if (errorBody.contains('already have')) {
          throw Exception('Username sudah digunakan');
        } else {
          throw Exception('Gagal mengubah user: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> deletePPPSecret(String id) async {
    try {
      // First, get the secret to make sure we have the correct ID
      final secrets = await getPPPSecret();
      final secret = secrets.firstWhere(
        (s) => s['.id'] == id,
        orElse: () => throw Exception('User tidak ditemukan'),
      );

      final response = await http.post(
        Uri.parse('$baseUrl/ppp/secret/remove'),
        headers: _headers,
        body: jsonEncode({
          '.id': secret['.id'],
        }),
      );

      if (response.statusCode != 200) {
        final errorBody = response.body.toLowerCase();
        if (errorBody.contains('no such item')) {
          throw Exception('User tidak ditemukan');
        } else {
          throw Exception('Gagal menghapus user: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> getTraffic(String interfaceId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/interface/$interfaceId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        // Calculate rates by comparing values over time
        await Future.delayed(const Duration(seconds: 1)); // Wait 1 second
        final secondResponse = await http.get(
          Uri.parse('$baseUrl/interface/$interfaceId'),
          headers: _headers,
        );
        if (secondResponse.statusCode == 200) {
          final secondData = jsonDecode(secondResponse.body);
          if (secondData is Map<String, dynamic>) {
            // Calculate TX/RX rates
            final txByteDiff = int.parse(secondData['tx-byte'] ?? '0') -
                int.parse(data['tx-byte'] ?? '0');
            final rxByteDiff = int.parse(secondData['rx-byte'] ?? '0') -
                int.parse(data['rx-byte'] ?? '0');
            final txPacketDiff = int.parse(secondData['tx-packet'] ?? '0') -
                int.parse(data['tx-packet'] ?? '0');
            final rxPacketDiff = int.parse(secondData['rx-packet'] ?? '0') -
                int.parse(data['rx-packet'] ?? '0');

            return {
              'tx-rate': (txByteDiff * 8 / 1000000), // Convert to Mbps
              'rx-rate': (rxByteDiff * 8 / 1000000), // Convert to Mbps
              'tx-packet-rate': txPacketDiff,
              'rx-packet-rate': rxPacketDiff,
              'total-tx-byte': data['tx-byte'],
              'total-rx-byte': data['rx-byte'],
              'total-tx-packet': data['tx-packet'],
              'total-rx-packet': data['rx-packet'],
              'tx-drop': data['tx-drop'],
              'rx-drop': data['rx-drop'],
              'tx-error': data['tx-error'],
              'rx-error': data['rx-error'],
            };
          }
        }
      }
      throw Exception('Invalid response format');
    } else {
      throw Exception('Failed to fetch traffic data: ${response.body}');
    }
  }

  /// Get system users from Mikrotik
  /// This endpoint provides user information including groups/roles
  /// Note: This endpoint may not be available on all devices/firmware versions
  Future<List<Map<String, dynamic>>> getSystemUsers() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/system/user'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((item) => item as Map<String, dynamic>).toList();
        } else {
          return [];
        }
      } else if (response.statusCode == 400) {
        // Handle case where endpoint is not available
        throw Exception(
            'Endpoint not available: /system/user - This endpoint may not be supported on your device/firmware version');
      } else {
        throw Exception(
            'Failed to fetch system users: Status ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Network error: Could not connect to the device');
      } else if (e is TimeoutException) {
        throw Exception('Timeout: The device did not respond in time');
      }
      throw Exception('Error fetching system users: $e');
    }
  }

  /// Get system user groups from Mikrotik
  /// This endpoint provides group/role information for users
  /// Note: This endpoint may not be available on all devices/firmware versions
  Future<List<Map<String, dynamic>>> getSystemUserGroups() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/system/user/group'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data.map((item) => item as Map<String, dynamic>).toList();
        } else {
          return [];
        }
      } else if (response.statusCode == 400) {
        // Handle case where endpoint is not available
        throw Exception(
            'Endpoint not available: /system/user/group - This endpoint may not be supported on your device/firmware version');
      } else {
        throw Exception(
            'Failed to fetch system user groups: Status ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Network error: Could not connect to the device');
      } else if (e is TimeoutException) {
        throw Exception('Timeout: The device did not respond in time');
      }
      throw Exception('Error fetching system user groups: $e');
    }
  }

  /// Fallback method to get user group from PPP secrets if system/user endpoint is not available
  Future<String> getUserGroupFromPPPSecret(String username) async {
    try {
      final secrets = await getPPPSecret();
      final userSecret = secrets.firstWhere(
        (secret) =>
            secret['name'] != null && secret['name'].toString() == username,
        orElse: () => {},
      );

      if (userSecret.isNotEmpty) {
        return userSecret['profile']?.toString() ?? 'No profile assigned';
      } else {
        return 'User not found';
      }
    } catch (e) {
      throw Exception('Error fetching user group from PPP secret: $e');
    }
  }
}
