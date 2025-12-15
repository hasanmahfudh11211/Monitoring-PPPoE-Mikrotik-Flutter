import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/mikrotik_provider.dart';
import '../providers/router_session_provider.dart';
import 'config_service.dart';

class LogSyncService {
  Timer? _syncTimer;
  bool _isSyncing = false;
  final BuildContext context;

  // Interval sinkronisasi (10 detik sesuai request user)
  static const Duration syncInterval = Duration(seconds: 10);

  // Notification Plugin
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Future to track initialization
  late Future<void> _initFuture;

  LogSyncService(this.context) {
    _initFuture = _initNotifications();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);

    // Request permission for Android 13+
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _showSystemNotification(String title, String body) async {
    // Ensure initialized
    await _initFuture;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'mikrotik_monitor_channel', // id
      'Mikrotik Alerts', // title
      channelDescription: 'Notifications for critical Mikrotik events',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(body),
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Gunakan ID unik berdasarkan waktu agar notifikasi menumpuk (tidak saling timpa)
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  void startAutoSync() {
    _syncTimer?.cancel();
    // Jalankan segera
    _syncLogs();
    // Lalu jadwalkan periodik
    _syncTimer = Timer.periodic(syncInterval, (_) => _syncLogs());
  }

  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _syncLogs() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      // 1. Ambil data sesi router
      if (!context.mounted) return;
      final session = context.read<RouterSessionProvider>();
      final routerId = session.routerId;

      // Pastikan sesi valid
      if (routerId == null || session.ip == null) {
        _isSyncing = false;
        return;
      }

      // 2. Ambil Log dari Router via Provider/Service
      if (!context.mounted) return;
      final provider = context.read<MikrotikProvider>();

      // Kita pakai method getLog() langsung dari service untuk menghindari refresh UI yang tidak perlu
      // atau bisa pakai provider.service.getLog()
      final logs = await provider.service.getLog();

      // 3. Filter Log Penting
      final filteredLogs = _filterLogs(logs);

      if (filteredLogs.isEmpty) {
        _isSyncing = false;
        return;
      }

      // 4. Kirim ke Backend
      await _sendToBackend(routerId, filteredLogs);

      // 5. Cek Notifikasi Lokal (Hanya jika ada log baru yang kritis)
      // Logika sederhana: Jika backend berhasil simpan (return saved_count > 0),
      // kita asumsikan ada log baru. Tapi backend return saved_count untuk semua log.
      // Untuk notifikasi real-time di HP, kita cek log paling baru dari list filteredLogs
      // Apakah log itu "Baru saja terjadi" (misal < 20 detik yang lalu)?
      _checkLocalNotification(filteredLogs);
    } catch (e) {
      debugPrint('[LogSync] Error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  List<Map<String, dynamic>> _filterLogs(List<Map<String, dynamic>> rawLogs) {
    final List<Map<String, dynamic>> result = [];

    for (var log in rawLogs) {
      final msg = log['message']?.toString().toLowerCase() ?? '';
      final topics = log['topics']?.toString().toLowerCase() ?? '';
      final timeStr = log['time']?.toString() ?? '';

      // Kriteria Filter
      bool isImportant = false;
      String action = 'SYSTEM';

      if (topics.contains('pppoe') || topics.contains('ppp')) {
        if (msg.contains('connected') ||
            msg.contains('disconnected') ||
            msg.contains('peer is not')) {
          isImportant = true;
          action = 'PPPoE';
        }
      } else if (topics.contains('account')) {
        // Filter out logs containing "->:" (usually repetitive hotspot/ppp login logs)
        if (!msg.contains('->:') &&
            (msg.contains('logged in') ||
                msg.contains('logged out') ||
                msg.contains('created') ||
                msg.contains('removed'))) {
          isImportant = true;
          action = 'ACCOUNT';
        }
      } else if (topics.contains('error') ||
          topics.contains('critical') ||
          topics.contains('failure')) {
        isImportant = true;
        action = 'ERROR';
      }

      if (isImportant) {
        // Parse waktu ke format ISO 8601 untuk Database & DateTime.parse
        final formattedTime = _parseMikrotikTime(timeStr);

        result.add({
          'action': action,
          'message': log['message'],
          'time':
              formattedTime, // Sekarang sudah pasti format YYYY-MM-DD HH:mm:ss
          'username': 'System',
        });
      }
    }
    return result;
  }

  // Helper untuk parsing waktu MikroTik yang aneh-aneh
  String _parseMikrotikTime(String timeStr) {
    final now = DateTime.now();
    final datePrefix =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // 1. Format "HH:mm:ss" (Log hari ini)
    if (RegExp(r'^\d{2}:\d{2}:\d{2}$').hasMatch(timeStr)) {
      return "$datePrefix $timeStr";
    }

    // 2. Format "MMM/dd HH:mm:ss" (Log lama/kemarin) -> "dec/15 14:30:00"
    // Regex: 3 huruf, slash, 2 digit, spasi, jam
    final match = RegExp(r'^([a-zA-Z]{3})/(\d{2})\s+(\d{2}:\d{2}:\d{2})$')
        .firstMatch(timeStr);
    if (match != null) {
      final monthStr = match.group(1)!.toLowerCase();
      final dayStr = match.group(2)!;
      final timePart = match.group(3)!;

      int month = 1;
      const months = [
        'jan',
        'feb',
        'mar',
        'apr',
        'may',
        'jun',
        'jul',
        'aug',
        'sep',
        'oct',
        'nov',
        'dec'
      ];
      final monthIndex = months.indexOf(monthStr);
      if (monthIndex != -1) {
        month = monthIndex + 1;
      }

      // Asumsi tahun ini.
      return "${now.year}-${month.toString().padLeft(2, '0')}-$dayStr $timePart";
    }

    // 3. Fallback: Jika gagal parse, pakai waktu sekarang saja daripada error
    return "$datePrefix 00:00:00";
  }

  Future<void> _sendToBackend(
      String routerId, List<Map<String, dynamic>> logs) async {
    final baseUrl = await ConfigService.getBaseUrl();
    final url = Uri.parse('$baseUrl/sync_router_logs.php');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'router_id': routerId,
        'logs': logs,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['saved_count'] > 0) {
        debugPrint('[LogSync] Saved ${data['saved_count']} new logs.');
      }
    }
  }

  // State untuk melacak log terakhir yang sudah diproses
  DateTime? _lastLogTime;

  /// Method publik untuk testing notifikasi secara manual
  /// Method publik untuk testing notifikasi secara manual
  Future<void> testNotification({String? title, String? body}) async {
    debugPrint('[LogSync] Testing notification...');
    await _showSystemNotification(
      title ?? "Mikrotik Monitor",
      body ?? "Sistem notifikasi berjalan dengan baik.",
    );
  }

  /// Cek status izin notifikasi
  Future<bool> checkPermission() async {
    return await Permission.notification.isGranted;
  }

  /// Request izin notifikasi
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Buka pengaturan aplikasi
  Future<void> openSettings() async {
    await openAppSettings();
  }

  Future<void> _checkLocalNotification(List<Map<String, dynamic>> logs) async {
    if (logs.isEmpty) return;

    // Cek preferensi user
    // Jika user mematikan notifikasi di setting, jangan lanjutkan
    try {
      // Import shared_preferences di file ini jika belum (sudah ada di import list file ini? belum, perlu cek)
      // Asumsi import 'package:shared_preferences/shared_preferences.dart'; perlu ditambahkan jika belum ada.
      // Tapi tunggu, LogSyncService tidak punya import shared_preferences di snippet sebelumnya.
      // Saya akan menambahkannya di langkah terpisah atau menggunakan ConfigService jika ada.
      // Untuk amannya, saya gunakan ConfigService jika memungkinkan, tapi ConfigService biasanya untuk URL.
      // Mari kita lihat import list nanti. Untuk sekarang saya tulis logikanya.
      // Ternyata file ini belum import shared_preferences.
      // Saya akan comment dulu bagian ini dan perbaiki import di langkah berikutnya.
    } catch (e) {
      debugPrint('[LogSync] Error checking prefs: $e');
    }

    // 1. Urutkan log dari yang terlama ke terbaru berdasarkan waktu
    try {
      logs.sort((a, b) {
        final timeA = DateTime.parse(a['time']);
        final timeB = DateTime.parse(b['time']);
        return timeA.compareTo(timeB);
      });
    } catch (e) {
      debugPrint('[LogSync] Error sorting logs: $e');
      return;
    }

    final latestLog = logs.last;
    final latestTime = DateTime.parse(latestLog['time']);
    final now = DateTime.now();

    debugPrint(
        '[LogSync] Checking notifications. Latest log time: $latestTime');

    // 2. Jika ini run pertama kali (aplikasi baru dibuka)
    if (_lastLogTime == null) {
      _lastLogTime = latestTime;
      debugPrint('[LogSync] Init: Last log time set to $_lastLogTime');

      // FIX: Jika log terakhir SANGAT BARU (kurang dari 30 detik yang lalu),
      // tetap tampilkan notifikasi meskipun ini run pertama.
      final difference = now.difference(latestTime).abs();
      if (difference.inSeconds < 30) {
        debugPrint(
            '[LogSync] First run but log is recent (${difference.inSeconds}s ago). Checking notification...');
        await _processLogForNotification(latestLog);
      }
      return;
    }

    // 3. Cek apakah ada log yang LEBIH BARU dari _lastLogTime
    int newLogsCount = 0;
    for (var log in logs) {
      final logTime = DateTime.parse(log['time']);

      // Jika log ini lebih baru dari checkpoint terakhir
      if (logTime.isAfter(_lastLogTime!)) {
        newLogsCount++;
        debugPrint('[LogSync] New log detected: ${log['message']} at $logTime');
        await _processLogForNotification(log);
      }
    }

    if (newLogsCount == 0) {
      debugPrint('[LogSync] No new logs since $_lastLogTime');
    }

    // 4. Update checkpoint waktu
    if (latestTime.isAfter(_lastLogTime!)) {
      _lastLogTime = latestTime;
      debugPrint('[LogSync] Updated last log time to $_lastLogTime');
    }
  }

  Future<void> _processLogForNotification(Map<String, dynamic> log) async {
    // 1. Cek preferensi user
    try {
      final prefs = await SharedPreferences.getInstance();
      final showNotifications = prefs.getBool('showNotifications') ?? true;
      if (!showNotifications) {
        debugPrint('[LogSync] Notification suppressed by user setting.');
        return;
      }
    } catch (e) {
      debugPrint('[LogSync] Error checking prefs: $e');
    }

    String msg = log['message'].toString();
    final lowerMsg = msg.toLowerCase();
    debugPrint('[LogSync] Processing notification for: $msg');

    // 2. Format Pesan agar lebih rapi
    // Contoh Log Asli: "<pppoe-gembong@wati>: connected"
    // Target: "User gembong@wati connected"

    // Regex untuk menangkap pattern <pppoe-USERNAME>: STATUS
    // Menangkap apa saja di dalam <pppoe-...> dan setelahnya
    final pppoeRegex = RegExp(r'<pppoe-(.+?)>: (.+)');
    final match = pppoeRegex.firstMatch(msg);

    String title = "Mikrotik Alert";
    String body = msg;

    if (match != null) {
      final username = match.group(1);
      final status = match.group(2);

      // Bersihkan status jika ada trailing chars
      String cleanStatus = status?.trim() ?? "";

      if (cleanStatus.toLowerCase() == "connected") {
        title = "PPPoE Connected";
        body = "User $username telah terhubung.";
      } else if (cleanStatus.toLowerCase() == "disconnected") {
        title = "PPPoE Disconnected";
        body = "User $username telah terputus.";
      } else {
        // Fallback untuk status lain
        body = "User $username: $cleanStatus";
      }
    } else {
      // Coba handling manual jika regex tidak match tapi ada keyword
      if (lowerMsg.contains('pppoe') || lowerMsg.contains('ppp')) {
        // Hapus karakter < > jika ada
        body = body.replaceAll('<', '').replaceAll('>', '');
        // Ganti "pppoe-" dengan "User "
        body = body.replaceAll('pppoe-', 'User ');
      }
    }

    // 3. Cek Payment
    if (lowerMsg.contains('added payment')) {
      title = "Pembayaran Berhasil";
      // Format: added payment: 1000000.0 (Cash) for user: username
      final paymentRegex =
          RegExp(r'added payment: ([\d\.]+) \((.+?)\) for user: (.+)');
      final payMatch = paymentRegex.firstMatch(msg);
      if (payMatch != null) {
        final amountStr = payMatch.group(1) ?? '0';
        final method = payMatch.group(2) ?? '-';
        final user = payMatch.group(3) ?? '-';
        try {
          final amount = double.parse(amountStr);
          // Manual formatting since we might not have NumberFormat here or want simple format
          // Using basic string manipulation for "Rp " prefix
          final amountFixed = amount.toStringAsFixed(0).replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.');
          body = "Diterima Rp $amountFixed ($method) dari $user";
        } catch (e) {
          body = msg;
        }
      }
    }

    // 4. Ignore Scheduler Error (User Request)
    if (lowerMsg.contains('scheduler') && lowerMsg.contains('failed')) {
      debugPrint('[LogSync] Scheduler error ignored.');
      return;
    }

    // 5. Cek filter dan Tampilkan
    if (lowerMsg.contains('disconnected') ||
        lowerMsg.contains('connected') ||
        lowerMsg.contains('peer is not') ||
        lowerMsg.contains('failure') ||
        lowerMsg.contains('failed') ||
        lowerMsg.contains('error') ||
        (lowerMsg.contains('logged in') && !lowerMsg.contains('via winbox')) ||
        (lowerMsg.contains('logged out') && !lowerMsg.contains('via winbox')) ||
        lowerMsg.contains('added payment')) {
      debugPrint('[LogSync] Triggering notification: $title - $body');
      await _showSystemNotification(title, body);
    } else {
      debugPrint('[LogSync] Log ignored by filter.');
    }
  }
}
