import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import '../services/mikrotik_service.dart';
import '../widgets/gradient_container.dart';
import 'package:provider/provider.dart';
import '../providers/router_session_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _addressController = TextEditingController();
  String _appVersion = '';
  String? _error;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _passwordController = TextEditingController();
  List<Map<String, String>> _savedLogins = [];
  late TabController _tabController;
  final _usernameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();

  // Add focus nodes
  final _ipFocus = FocusNode();
  final _portFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _addressController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    // Dispose focus nodes
    _ipFocus.dispose();
    _portFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLastSuccessfulLogin();
    _loadSavedLogins();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${info.version}';
    });
  }

  Future<void> _loadSavedLogins() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('mikrotik_logins') ?? [];
      if (!mounted) return;

      // Filter and clean up saved logins
      final cleanedLogins = data.where((e) {
        try {
          final login = Map<String, String>.from(jsonDecode(e));
          final address = login['address'] ?? '';
          final username = login['username'] ?? '';

          // Basic validation
          if (address.isEmpty || username.isEmpty) return false;

          // Validate address format (ip:port)
          final parts = address.split(':');
          if (parts.length != 2) return false;

          // Validate IP format
          final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
          if (!ipRegex.hasMatch(parts[0])) return false;

          // Validate port
          final port = int.tryParse(parts[1]);
          if (port == null || port <= 0 || port > 65535) return false;

          return true;
        } catch (e) {
          return false;
        }
      }).toList();

      setState(() {
        _savedLogins = cleanedLogins
            .map((e) => Map<String, String>.from(jsonDecode(e)))
            .toList();
      });

      // Save back the cleaned list if different
      if (cleanedLogins.length != data.length) {
        await prefs.setStringList('mikrotik_logins', cleanedLogins);
      }
    } catch (e) {
      debugPrint('Error loading saved logins: $e');
      setState(() {
        _savedLogins = [];
      });
    }
  }

  Future<void> _loadLastSuccessfulLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIp = prefs.getString('ip');
      final lastPort = prefs.getString('port');
      final lastUsername = prefs.getString('username');
      final lastPassword = prefs.getString('password');

      if (mounted && lastIp != null && lastPort != null) {
        setState(() {
          _ipController.text = lastIp;
          _portController.text = lastPort;
          _usernameController.text = lastUsername ?? '';
          _passwordController.text = lastPassword ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading last login: $e');
    }
  }

  Future<void> _saveLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final loginData = {
      'address': '${_ipController.text}:${_portController.text}',
      'username': _usernameController.text,
      'password': _passwordController.text,
    };

    // Load existing logins
    final savedLogins = prefs.getStringList('mikrotik_logins') ?? [];

    // Remove existing login with same address and username if exists
    savedLogins.removeWhere((e) {
      try {
        final existing = Map<String, String>.from(jsonDecode(e));
        return existing['address'] == loginData['address'] &&
            existing['username'] == loginData['username'];
      } catch (_) {
        return false;
      }
    });

    // Add new login data
    savedLogins.add(jsonEncode(loginData));

    // Save back to SharedPreferences
    await prefs.setStringList('mikrotik_logins', savedLogins);

    // Reload saved logins to update the list
    await _loadSavedLogins();

    if (!mounted) return;

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Login berhasil disimpan!'),
        backgroundColor: Colors.green,
      ),
    );

    // Switch to saved logins tab
    _tabController.animateTo(1);
  }

  Future<void> _deleteLogin(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('mikrotik_logins') ?? [];
    data.removeAt(index);
    await prefs.setStringList('mikrotik_logins', data);
    await _loadSavedLogins();
  }

  void _fillForm(Map<String, String> login) {
    final parts = login['address']?.split(':') ?? [];
    setState(() {
      // Safe array access to prevent null pointer exceptions
      if (parts.length >= 2) {
        _ipController.text = parts[0];
        _portController.text = parts[1];
      } else {
        _ipController.text = '';
        _portController.text = '';
      }
      _usernameController.text = login['username'] ?? '';
      _passwordController.text = login['password'] ?? '';
      _tabController.index = 0;
    });
  }

  void _showErrorDialog(String error) {
    // Helper function to format error message
    String getFormattedErrorMessage(String errorType, String ipAddress) {
      if (errorType == 'timeout') {
        return '''Koneksi Timeout (10 detik)
Kemungkinan Penyebab:
• Router tidak menyala
• IP Address salah
• Jaringan tidak stabil
Solusi:
1. Periksa router dan koneksi jaringan
2. Pastikan IP benar: $ipAddress
3. Coba hubungkan kembali''';
      } else {
        return '''Login Gagal
Username atau password salah
Solusi:
1. Periksa kembali username
2. Periksa kembali password
3. Pastikan huruf besar/kecil sudah benar''';
      }
    }

    // Check if dark mode is enabled
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              // Icon
              Icon(
                Icons.error_outline,
                color: Colors.red[400],
                size: 28,
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                'Gagal Terhubung',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              // Error message in Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Parse and display error message
                      ...getFormattedErrorMessage(
                              error.contains('timeout') ? 'timeout' : 'login',
                              _ipController.text // Use the actual IP from input
                              )
                          .split('\n')
                          .map((line) {
                        bool isBold = line == 'Koneksi Timeout (10 detik)' ||
                            line == 'Login Gagal' ||
                            line == 'Username atau password salah' ||
                            line == 'Kemungkinan Penyebab:' ||
                            line == 'Solusi:';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: isDark ? Colors.white : Colors.red[400],
                              fontWeight:
                                  isBold ? FontWeight.bold : FontWeight.normal,
                            ),
                            textAlign: line == 'Koneksi Timeout (10 detik)' ||
                                    line == 'Login Gagal' ||
                                    line == 'Username atau password salah'
                                ? TextAlign.center
                                : TextAlign.left,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // OK Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessDialog(String username) {
    // Capitalize first letter of username
    final capitalizedUsername =
        username[0].toUpperCase() + username.substring(1);

    // Check if dark mode is enabled
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.green[900] : Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.green[400],
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              // Title
              Text(
                'Login Berhasil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Welcome message
              Text(
                'Selamat datang, $capitalizedUsername!',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.green[300] : Colors.green[400],
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // OK Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      // Navigate to dashboard
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    print('[LOGIN DEBUG] Starting login process...');
    print('[LOGIN DEBUG] IP: ${_ipController.text}');
    print('[LOGIN DEBUG] Port: ${_portController.text}');
    print('[LOGIN DEBUG] Username: ${_usernameController.text}');

    try {
      // Show loading dialog
      if (mounted) {
        // Check if dark mode is enabled
        final isDark = Theme.of(context).brightness == Brightness.dark;

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return WillPopScope(
              onWillPop: () async => false,
              child: AlertDialog(
                backgroundColor:
                    isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Menghubungkan ke Router',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[800]
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_ipController.text}:${_portController.text}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                          fontFamily: 'monospace',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mohon tunggu...',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
      final address = '${_ipController.text}:${_portController.text}';
      final service = MikrotikService(
        ip: _ipController.text,
        port: _portController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        enableLogging: true, // Enable logging in service
      );

      print('[LOGIN DEBUG] Service initialized. Calling getIdentity()...');
      await service.getIdentity();
      print('[LOGIN DEBUG] getIdentity() success.');

      // Ambil routerId dengan fallback berjenjang (serial-number -> software-id -> identity)
      print('[LOGIN DEBUG] Calling getRouterSerialOrId()...');
      final routerId = await service.getRouterSerialOrId();
      print('[LOGIN DEBUG] Router ID obtained: $routerId');

      if (routerId.isEmpty) {
        throw Exception('Gagal mengambil identitas router');
      }
      // Simpan session router secara global
      Provider.of<RouterSessionProvider>(context, listen: false).saveSession(
        routerId: routerId,
        ip: _ipController.text,
        port: _portController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      // Save login data ke shared prefs (opsional)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ip', _ipController.text);
      await prefs.setString('port', _portController.text);
      await prefs.setString('username', _usernameController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setString('router_id', routerId);

      // Backfill dimatikan: MENYEBABKAN DATA TERPINDAH ROUTER
      // Backfill otomatis mengubah router_id semua data legacy ke router baru
      // ini menyebabkan data "hilang" karena ter-assign ke router yang salah
      //
      // Jika perlu backfill, lakukan MANUAL via API atau perbaiki dulu logic backfill
      // untuk TIDAK memindahkan data yang sudah punya router_id yang berbeda
      //
      // ignore: unawaited_futures
      // ApiService.backfillRouterId(routerId: routerId).catchError((e) {
      //   // ignore: avoid_print
      //   print('[LOGIN][BACKFILL] Silent fail: $e');
      //   return <String, dynamic>{'success': false};
      // });

      // Sinkronisasi PPP users dipindahkan ke halaman yang membutuhkan data database
      // (All Users, ODP, Billing) agar login lebih cepat

      // Save to login history
      final loginData = {
        'address': address,
        'username': _usernameController.text,
        'password': _passwordController.text,
      };

      final savedLogins = prefs.getStringList('mikrotik_logins') ?? [];
      savedLogins.removeWhere((e) {
        final m = Map<String, String>.from(jsonDecode(e));
        return m['address'] == loginData['address'] &&
            m['username'] == loginData['username'];
      });
      savedLogins.add(jsonEncode(loginData));
      await prefs.setStringList('mikrotik_logins', savedLogins);

      print('[LOGIN DEBUG] Login successful. Saving history and navigating...');

      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog
      _showSuccessDialog(_usernameController.text);
    } catch (e) {
      print('[LOGIN DEBUG] Login FAILED. Error: $e');
      if (!mounted) return;

      // Close loading dialog if it's showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });

      // Show error dialog
      _showErrorDialog(_error ?? 'Terjadi kesalahan yang tidak diketahui');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildSavedLoginsTab() {
    // Check if dark mode is enabled
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_savedLogins.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada login tersimpan',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey,
          ),
        ),
      );
    } else {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        itemCount: _savedLogins.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: isDark ? Colors.grey[700] : Colors.grey[300],
        ),
        itemBuilder: (context, index) {
          final login = _savedLogins[index];
          final address = login['address'] ?? '';
          final username = login['username'] ?? '';

          final parts = address.split(':');
          if (parts.length != 2) return const SizedBox.shrink();

          final ip = parts[0];
          final port = parts[1];

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            onTap: () => _fillForm(login),
            title: Row(
              children: [
                Icon(Icons.router_outlined,
                    size: 16, color: isDark ? Colors.white70 : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$ip:$port',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Icon(Icons.person_outline,
                    size: 16, color: isDark ? Colors.white70 : Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    username,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete,
                  color: isDark ? Colors.red[300] : Colors.red),
              onPressed: () {
                _deleteLogin(index);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Login berhasil dihapus!'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if dark mode is enabled
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Icon(Icons.exit_to_app, color: Colors.red, size: 32),
                SizedBox(width: 10),
                Text('Keluar Aplikasi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    )),
              ],
            ),
            content: Text('Apakah Anda yakin ingin keluar dari aplikasi?',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : Colors.black,
                )),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Batal',
                    style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Keluar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return shouldExit ?? false;
      },
      child: Stack(
        children: [
          GradientContainer(
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Card(
                            elevation: 6,
                            color:
                                isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20.0, vertical: 20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 4),
                                  // Logo Mikrotik PNG - use different assets for light and dark mode
                                  Image.asset(
                                    isDark
                                        ? 'assets/Mikrotik-logo-white.png'
                                        : 'assets/Mikrotik-logo.png',
                                    height: 48,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Mikrotik PPPoE Monitor',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black38),
                                  ),
                                  const SizedBox(height: 20),
                                  TabBar(
                                    controller: _tabController,
                                    tabs: const [
                                      Tab(text: 'LOG IN'),
                                      Tab(text: 'SAVED'),
                                    ],
                                    labelColor:
                                        isDark ? Colors.blue[300] : Colors.blue,
                                    unselectedLabelColor: isDark
                                        ? Colors.white70
                                        : Colors.black38,
                                    indicatorColor: Colors.blue,
                                    dividerColor:
                                        isDark ? Colors.grey[700] : null,
                                  ),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    height: 320,
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: [
                                        // Tab 1: LOG IN
                                        SingleChildScrollView(
                                          child: Form(
                                            key: _formKey,
                                            child: Column(
                                              children: [
                                                // IP and Port fields in a row
                                                Row(
                                                  children: [
                                                    // IP field
                                                    Expanded(
                                                      flex: 2,
                                                      child: TextFormField(
                                                        controller:
                                                            _ipController,
                                                        focusNode: _ipFocus,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        onFieldSubmitted: (_) {
                                                          FocusScope.of(context)
                                                              .requestFocus(
                                                                  _portFocus);
                                                        },
                                                        decoration:
                                                            InputDecoration(
                                                          labelText:
                                                              'IP Address',
                                                          hintText:
                                                              '192.168.1.1',
                                                          border:
                                                              const UnderlineInputBorder(),
                                                          labelStyle: TextStyle(
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black54,
                                                          ),
                                                          hintStyle: TextStyle(
                                                            color: isDark
                                                                ? Colors.white38
                                                                : Colors
                                                                    .black38,
                                                          ),
                                                        ),
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white
                                                              : Colors.black,
                                                        ),
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter
                                                              .allow(RegExp(
                                                                  r'[0-9.]')),
                                                        ],
                                                        validator: (value) {
                                                          if (value == null ||
                                                              value.isEmpty) {
                                                            return 'Masukkan IP';
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    // Port field
                                                    Expanded(
                                                      child: TextFormField(
                                                        controller:
                                                            _portController,
                                                        focusNode: _portFocus,
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        onFieldSubmitted: (_) {
                                                          FocusScope.of(context)
                                                              .requestFocus(
                                                                  _usernameFocus);
                                                        },
                                                        decoration:
                                                            InputDecoration(
                                                          labelText: 'Port',
                                                          hintText: '80',
                                                          border:
                                                              const UnderlineInputBorder(),
                                                          labelStyle: TextStyle(
                                                            color: isDark
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black54,
                                                          ),
                                                          hintStyle: TextStyle(
                                                            color: isDark
                                                                ? Colors.white38
                                                                : Colors
                                                                    .black38,
                                                          ),
                                                        ),
                                                        style: TextStyle(
                                                          color: isDark
                                                              ? Colors.white
                                                              : Colors.black,
                                                        ),
                                                        inputFormatters: [
                                                          FilteringTextInputFormatter
                                                              .digitsOnly,
                                                        ],
                                                        validator: (value) {
                                                          if (value == null ||
                                                              value.isEmpty) {
                                                            return 'Masukkan port';
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller:
                                                      _usernameController,
                                                  focusNode: _usernameFocus,
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  onFieldSubmitted: (_) {
                                                    FocusScope.of(context)
                                                        .requestFocus(
                                                            _passwordFocus);
                                                  },
                                                  decoration: InputDecoration(
                                                    labelText: 'Username',
                                                    hintText: 'admin',
                                                    border:
                                                        const UnderlineInputBorder(),
                                                    labelStyle: TextStyle(
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black54,
                                                    ),
                                                    hintStyle: TextStyle(
                                                      color: isDark
                                                          ? Colors.white38
                                                          : Colors.black38,
                                                    ),
                                                  ),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Masukkan username';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 16),
                                                TextFormField(
                                                  controller:
                                                      _passwordController,
                                                  focusNode: _passwordFocus,
                                                  textInputAction:
                                                      TextInputAction.done,
                                                  onFieldSubmitted: (_) {
                                                    // Just unfocus to close the keyboard
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                  },
                                                  decoration: InputDecoration(
                                                    labelText: 'Password',
                                                    border:
                                                        const UnderlineInputBorder(),
                                                    labelStyle: TextStyle(
                                                      color: isDark
                                                          ? Colors.white70
                                                          : Colors.black54,
                                                    ),
                                                    suffixIcon: IconButton(
                                                      icon: Icon(
                                                        _obscurePassword
                                                            ? Icons
                                                                .visibility_off
                                                            : Icons.visibility,
                                                        color: isDark
                                                            ? Colors.white70
                                                            : Colors.black54,
                                                      ),
                                                      onPressed: () {
                                                        setState(() {
                                                          _obscurePassword =
                                                              !_obscurePassword;
                                                        });
                                                      },
                                                    ),
                                                  ),
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? Colors.white
                                                        : Colors.black,
                                                  ),
                                                  obscureText: _obscurePassword,
                                                  validator: (value) {
                                                    if (value == null ||
                                                        value.isEmpty) {
                                                      return 'Masukkan password';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                                const SizedBox(height: 38),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: _isLoading
                                                            ? null
                                                            : _saveLogin,
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              isDark
                                                                  ? Colors
                                                                      .grey[700]
                                                                  : Colors
                                                                      .black87,
                                                          foregroundColor:
                                                              Colors.white,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          elevation: 1,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 12),
                                                        ),
                                                        child:
                                                            const Text('SAVE'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: _isLoading
                                                            ? null
                                                            : _login,
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              Colors.blue,
                                                          foregroundColor:
                                                              Colors.white,
                                                          shape:
                                                              RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                          ),
                                                          elevation: 1,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 12),
                                                        ),
                                                        child: _isLoading
                                                            ? const SizedBox(
                                                                width: 18,
                                                                height: 18,
                                                                child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Colors
                                                                        .white),
                                                              )
                                                            : const Text(
                                                                'CONNECT'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // Tab 2: SAVED
                                        _buildSavedLoginsTab(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Version display in the footer, completely outside the card structure
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black38,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
