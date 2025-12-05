import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/mikrotik_service.dart';
import '../services/mikrotik_native_service.dart';
import 'mikrotik_provider.dart';

class RouterSessionProvider extends ChangeNotifier {
  String? routerId; // serial-number
  String? ip;
  String? port;
  String? username;
  String? password;

  RouterSessionProvider() {
    // Auto-restore sesi dari SharedPreferences saat provider dibuat
    Future.microtask(_loadFromPrefs);
  }

  // Persistent Service Instance
  MikrotikService? _service;
  MikrotikService? get service => _service;

  // Helper to get or create service
  Future<MikrotikService> getService() async {
    if (_service != null) return _service!;

    // If service is null, try to recreate from saved session
    if (ip != null && port != null && username != null && password != null) {
      final prefs = await SharedPreferences.getInstance();
      final useNativeApi = prefs.getBool('useNativeApi') ?? false;

      if (useNativeApi || port == '8728' || port == '8729') {
        _service = MikrotikNativeService(
          ip: ip,
          port: port,
          username: username,
          password: password,
        );
      } else {
        _service = MikrotikService(
          ip: ip,
          port: port,
          username: username,
          password: password,
        );
      }
      return _service!;
    }

    throw Exception('Session not initialized');
  }

  // Persistent MikrotikProvider Instance
  MikrotikProvider? _mikrotikProvider;
  MikrotikProvider? get mikrotikProvider => _mikrotikProvider;

  Future<MikrotikProvider> getMikrotikProvider() async {
    if (_mikrotikProvider != null) return _mikrotikProvider!;

    final service = await getService();
    _mikrotikProvider = MikrotikProvider(service);
    return _mikrotikProvider!;
  }

  void saveSession({
    required String routerId,
    required String ip,
    required String port,
    required String username,
    required String password,
  }) {
    this.routerId = routerId;
    this.ip = ip;
    this.port = port;
    this.username = username;
    this.password = password;

    // Reset service on new session
    _disposeService();

    _persist();
    notifyListeners();
  }

  void clearSession() {
    routerId = null;
    ip = null;
    port = null;
    username = null;
    password = null;

    _disposeService();

    _clearPrefs();
    notifyListeners();
  }

  void _disposeService() {
    if (_service is MikrotikNativeService) {
      (_service as MikrotikNativeService).dispose();
    }
    _service = null;
    // MikrotikProvider will be recreated when needed
    _mikrotikProvider = null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('router_id', routerId ?? '');
    await prefs.setString('ip', ip ?? '');
    await prefs.setString('port', port ?? '');
    await prefs.setString('username', username ?? '');
    await prefs.setString('password', password ?? '');
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('router_id');
    await prefs.remove('ip');
    await prefs.remove('port');
    await prefs.remove('username');
    await prefs.remove('password');
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rid = prefs.getString('router_id');
    final pip = prefs.getString('ip');
    final pport = prefs.getString('port');
    final usr = prefs.getString('username');
    final pwd = prefs.getString('password');
    if ((rid?.isNotEmpty ?? false) &&
        (pip?.isNotEmpty ?? false) &&
        (pport?.isNotEmpty ?? false) &&
        (usr?.isNotEmpty ?? false) &&
        (pwd?.isNotEmpty ?? false)) {
      routerId = rid;
      ip = pip;
      port = pport;
      username = usr;
      password = pwd;
      notifyListeners();
    }
  }
}
