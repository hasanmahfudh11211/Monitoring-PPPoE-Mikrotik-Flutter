import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _persist();
    notifyListeners();
  }

  void clearSession() {
    routerId = null;
    ip = null;
    port = null;
    username = null;
    password = null;
    _clearPrefs();
    notifyListeners();
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
    if ((rid?.isNotEmpty ?? false) && (pip?.isNotEmpty ?? false) && (pport?.isNotEmpty ?? false) && (usr?.isNotEmpty ?? false) && (pwd?.isNotEmpty ?? false)) {
      routerId = rid;
      ip = pip;
      port = pport;
      username = usr;
      password = pwd;
      notifyListeners();
    }
  }
}
