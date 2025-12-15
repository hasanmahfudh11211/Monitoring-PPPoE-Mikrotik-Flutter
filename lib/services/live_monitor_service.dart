import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'mikrotik_service.dart';

class LiveMonitorService {
  static final LiveMonitorService _instance = LiveMonitorService._internal();
  factory LiveMonitorService() => _instance;
  LiveMonitorService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Timer? _timer;
  MikrotikService? _service;
  bool _isMonitoring = false;

  // Cache for traffic calculation
  Map<String, dynamic>? _lastInterfaceData;
  String? _monitoredInterfaceName;

  // Notification ID for live monitor
  static const int _notificationId = 888;
  static const String _channelId = 'mikrotik_live_monitor';
  static const String _channelName = 'Live Monitor';

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  void startMonitoring(MikrotikService service, String routerName, String ip) {
    // Always stop first to ensure clean state
    stopMonitoring();

    if (_isMonitoring) return;

    _service = service;
    _isMonitoring = true;
    _monitoredInterfaceName = null; // Reset interface selection
    _lastInterfaceData = null;

    // Start immediately
    _updateNotification(routerName, ip);

    // Schedule periodic updates (every 1 second)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateNotification(routerName, ip);
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _timer?.cancel();
    _timer = null;
    _service = null;
    _notificationsPlugin.cancel(_notificationId);
  }

  Future<void> _updateNotification(String routerName, String ip) async {
    if (_service == null || !_isMonitoring) return;

    try {
      // 1. Fetch System Resource
      final resource = await _service!.getResource();
      final cpu = resource['cpu-load'] ?? '0';
      final uptime = resource['uptime'] ?? '-';

      // Memory calculation
      final totalMem = int.tryParse(resource['total-memory'] ?? '0') ?? 0;
      final freeMem = int.tryParse(resource['free-memory'] ?? '0') ?? 0;
      final usedMem = totalMem - freeMem;
      final totalMemGb = (totalMem / (1024 * 1024 * 1024)).toStringAsFixed(1);
      final usedMemGb = (usedMem / (1024 * 1024 * 1024)).toStringAsFixed(1);

      // 2. Fetch Traffic (Heuristic: Find first running interface or use cached one)
      String txRate = "0 bps";
      String rxRate = "0 bps";

      try {
        // We need to fetch interfaces to calculate rate manually or use getTraffic
        // Since getTraffic blocks for 1s, calling it here might be okay since we are in a timer
        // But we need to know WHICH interface.

        if (_monitoredInterfaceName == null) {
          final interfaces = await _service!.getInterface();
          // Find first running interface, prefer 'ether1' or 'pppoe-out1'
          final running =
              interfaces.where((i) => i['running'] == 'true').toList();
          if (running.isNotEmpty) {
            // Simple heuristic: prefer one with 'ether' or 'wan' in name
            var target = running.firstWhere(
                (i) => (i['name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains('ether'),
                orElse: () => running.first);
            _monitoredInterfaceName = target['name'];
          }
        }

        if (_monitoredInterfaceName != null) {
          // Use getTraffic from service which handles the diff
          // Note: This takes 1 second to complete!
          final traffic = await _service!.getTraffic(_monitoredInterfaceName!);

          final tx = (traffic['tx-rate'] as double? ?? 0.0);
          final rx = (traffic['rx-rate'] as double? ?? 0.0);

          txRate = _formatRate(tx);
          rxRate = _formatRate(rx);
        }
      } catch (e) {
        debugPrint('Error fetching traffic: $e');
      }

      // 3. Build Notification
      final title = "Rx: $rxRate, Tx: $txRate now";
      final body = "$routerName ($uptime)\n"
          "CPU: $cpu% | Mem: $usedMemGb GiB / $totalMemGb GiB";

      // CRITICAL FIX: Check if monitoring was stopped during async operations
      if (!_isMonitoring) return;

      await _showNotification(title, body);
    } catch (e) {
      debugPrint('LiveMonitor Error: $e');
      // Don't stop monitoring on error, just skip this update
    }
  }

  String _formatRate(double mbps) {
    if (mbps >= 1.0) {
      return "${mbps.toStringAsFixed(1)} Mbps";
    } else {
      final kbps = mbps * 1000;
      return "${kbps.toStringAsFixed(1)} kbps";
    }
  }

  Future<void> _showNotification(String title, String body) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Real-time router statistics',
      importance: Importance.low, // LOW importance for silent updates
      priority: Priority.low,
      ongoing: true, // Persistent
      autoCancel: false,
      showWhen: false,
      onlyAlertOnce: true, // Alert only once
      playSound: false,
      enableVibration: false,
      styleInformation: BigTextStyleInformation(body),
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      _notificationId,
      title,
      body,
      platformChannelSpecifics,
    );
  }
}
