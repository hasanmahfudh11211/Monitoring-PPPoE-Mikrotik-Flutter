import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import '../services/mikrotik_service.dart';
import '../widgets/gradient_container.dart';
import 'package:provider/provider.dart';
import '../providers/router_session_provider.dart';
import '../services/mikrotik_native_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _addressController = TextEditingController();

  // _error field removed
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  final _passwordController = TextEditingController();
  List<Map<String, String>> _savedLogins = [];
  late TabController _tabController;
  final _usernameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _rememberMe = true; // Default to true since checkbox is removed
  bool _useNativeApi = false;

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
    _tabController.addListener(() {
      setState(() {});
    });
    _loadLastSuccessfulLogin();
    _loadSavedLogins();
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
      final rememberMe = prefs.getBool('rememberMe') ?? false;
      final useNativeApi = prefs.getBool('useNativeApi') ?? false;

      if (mounted && lastIp != null && lastPort != null) {
        setState(() {
          _ipController.text = lastIp;
          _portController.text = lastPort;
          _usernameController.text = lastUsername ?? '';
          _passwordController.text = lastPassword ?? '';
          _rememberMe = rememberMe;
          _useNativeApi = useNativeApi;
        });
      }
    } catch (e) {
      debugPrint('Error loading last login: $e');
    }
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
        return '''Koneksi Timeout (5 detik)
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
    });

    String ip = _ipController.text;
    String port = _portController.text;
    String username = _usernameController.text;
    String password = _passwordController.text;

    // Helper function to create service
    MikrotikService createService(bool useNative) {
      if (useNative) {
        return MikrotikNativeService(
          ip: ip,
          port: port,
          username: username,
          password: password,
          enableLogging: true,
        );
      } else {
        return MikrotikService(
          ip: ip,
          port: port,
          username: username,
          password: password,
          enableLogging: true,
        );
      }
    }

    // Determine initial protocol priority
    bool tryNativeFirst = _useNativeApi || port == '8728' || port == '8729';
    String? firstError;

    try {
      // --- ATTEMPT 1 ---
      print('[LOGIN] Attempt 1: ${tryNativeFirst ? "Native API" : "REST API"}');
      final service1 = createService(tryNativeFirst);
      await service1.getIdentity();

      // If success, save preference
      _useNativeApi = tryNativeFirst;
      print('[LOGIN] Attempt 1 Success!');
    } catch (e1) {
      firstError = e1.toString();
      print('[LOGIN] Attempt 1 Failed: $e1');

      // --- ATTEMPT 2 (Fallback) ---
      try {
        print(
            '[LOGIN] Attempt 2: ${!tryNativeFirst ? "Native API" : "REST API"} (Fallback)');
        final service2 = createService(!tryNativeFirst);
        await service2.getIdentity();

        // If success, update preference to the one that worked
        _useNativeApi = !tryNativeFirst;
        print('[LOGIN] Attempt 2 Success! Switched protocol.');
      } catch (e2) {
        print('[LOGIN] Attempt 2 Failed: $e2');
        setState(() {
          _isLoading = false;
        });

        // Show error dialog
        _showErrorDialog(firstError);
        return;
      }
    }

    // --- LOGIN SUCCESS ---
    try {
      // Save credentials
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('ip', ip);
        await prefs.setString('port', port);
        await prefs.setString('username', username);
        await prefs.setString('password', password);
        await prefs.setBool('rememberMe', true);
        await prefs.setBool('useNativeApi', _useNativeApi);
      } else {
        // Only remove specific keys, DO NOT clear all prefs (which would wipe saved logins)
        await prefs.remove('ip');
        await prefs.remove('port');
        await prefs.remove('username');
        await prefs.remove('password');
        await prefs.remove('rememberMe');
        await prefs.remove('useNativeApi');
      }

      // Simpan session router secara global
      if (mounted) {
        final sessionProvider = context.read<RouterSessionProvider>();
        sessionProvider.saveSession(
          routerId: '$ip:$port',
          ip: ip,
          port: port,
          username: username,
          password: password,
        );
      }

      // Save to login history
      final loginData = {
        'address': '$ip:$port',
        'username': username,
        'password': password,
      };
      final savedLogins = prefs.getStringList('mikrotik_logins') ?? [];
      savedLogins.removeWhere((e) {
        try {
          final m = Map<String, String>.from(jsonDecode(e));
          return m['address'] == loginData['address'] &&
              m['username'] == loginData['username'];
        } catch (_) {
          return false;
        }
      });
      savedLogins.add(jsonEncode(loginData));
      await prefs.setStringList('mikrotik_logins', savedLogins);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // Show success dialog
      _showSuccessDialog(username);
    } catch (e) {
      print('[LOGIN] Error saving session: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
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
        shrinkWrap: true, // Fix unbounded height error
        physics:
            const NeverScrollableScrollPhysics(), // Disable internal scrolling
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
                      fontSize: 18,
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
                      fontSize: 16,
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
          // Background
          const GradientContainer(
            child: SizedBox.expand(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 32, // Raised version text
            child: Center(
              child: Material(
                type: MaterialType.transparency,
                child: Text(
                  'v1.0',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    decoration:
                        TextDecoration.none, // Explicitly remove underline
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(
                          height: 80), // Further increased top spacing for card
                      // Login Card
                      Container(
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(
                                height: 20), // Reduced top spacing for logo
                            // Logo
                            Center(
                              child: Image.asset(
                                isDark
                                    ? 'assets/Mikrotik-logo-white.png'
                                    : 'assets/Mikrotik-logo.png',
                                width: MediaQuery.of(context).size.width *
                                    0.7, // Responsive width (70% of screen)
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Column(
                                    children: [
                                      Icon(
                                        Icons.router,
                                        size: 60,
                                        color: isDark
                                            ? Colors.white
                                            : Colors
                                                .black, // Adjusted for card bg
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'MIKROTIK',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : Colors
                                                  .black, // Adjusted for card bg
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(
                                height:
                                    12), // Spacing between logo and subtitle
                            Text(
                              'Mikrotik PPPoE Monitor',
                              style: TextStyle(
                                fontSize: 16, // Increased font size
                                fontWeight: FontWeight.bold, // Bold text
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey, // Adjusted for card bg
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(
                                height: 32), // Increased spacing before tabs
                            // Tabs
                            TabBar(
                              controller: _tabController,
                              labelColor: Colors.blue,
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: Colors.blue,
                              indicatorWeight: 3,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              tabs: const [
                                Tab(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        bottom: 16), // Increased padding
                                    child: Text('LOG IN'),
                                  ),
                                ),
                                Tab(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        bottom: 16), // Increased padding
                                    child: Text('SAVED'),
                                  ),
                                ),
                              ],
                            ),
                            // Dynamic Content based on Tab
                            // Dynamic Content based on Tab
                            if (_tabController.index == 0)
                              // Login Form Tab
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 32, 24,
                                    24), // Increased top padding to 32 to match button gap
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    // mainAxisAlignment: MainAxisAlignment.center, // Removed to reduce top gap
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller: _ipController,
                                              focusNode: _ipFocus,
                                              style: const TextStyle(
                                                  fontSize:
                                                      16), // Increased font size
                                              decoration: InputDecoration(
                                                labelText: 'IP Address',
                                                prefixIcon:
                                                    const Icon(Icons.dns),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'IP wajib diisi';
                                                }
                                                return null;
                                              },
                                              onFieldSubmitted: (_) {
                                                FocusScope.of(context)
                                                    .requestFocus(_portFocus);
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 1,
                                            child: TextFormField(
                                              controller: _portController,
                                              focusNode: _portFocus,
                                              style: const TextStyle(
                                                  fontSize:
                                                      16), // Increased font size
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                labelText: 'Port',
                                                hintText: '8728',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return 'Port wajib';
                                                }
                                                return null;
                                              },
                                              onFieldSubmitted: (_) {
                                                FocusScope.of(context)
                                                    .requestFocus(
                                                        _usernameFocus);
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _usernameController,
                                        focusNode: _usernameFocus,
                                        style: const TextStyle(
                                            fontSize:
                                                16), // Increased font size
                                        decoration: InputDecoration(
                                          labelText: 'Username',
                                          prefixIcon: const Icon(Icons.person),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Username wajib diisi';
                                          }
                                          return null;
                                        },
                                        onFieldSubmitted: (_) {
                                          FocusScope.of(context)
                                              .requestFocus(_passwordFocus);
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocus,
                                        style: const TextStyle(
                                            fontSize:
                                                16), // Increased font size
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          prefixIcon: const Icon(Icons.lock),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onFieldSubmitted: (_) => _login(),
                                      ),
                                      const SizedBox(height: 32),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 20),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : const Text(
                                                  'LOG IN',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              // Saved Logins Tab
                              _buildSavedLoginsTab()
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
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
