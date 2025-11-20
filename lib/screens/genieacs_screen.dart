import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/gradient_container.dart';
import 'package:provider/provider.dart';

import '../services/genieacs_service.dart';
import '../services/genieacs_config_service.dart';
import '../main.dart';

class GenieACSScreen extends StatefulWidget {
  const GenieACSScreen({Key? key}) : super(key: key);

  @override
  State<GenieACSScreen> createState() => _GenieACSScreenState();
}

class _GenieACSScreenState extends State<GenieACSScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = false;
  bool _isRefreshing = false;
  GenieACSService? _service;
  List<Map<String, dynamic>> _devices = [];
  Timer? _searchDebounce;
  Timer? _updateTimer;

  // Filter and sort options
  String _sortOption = 'Last Inform (Newest)';
  String _statusFilter = 'Semua';
  String _rxFilter = 'Semua';
  final List<String> _sortOptions = [
    'Last Inform (Newest)',
    'Last Inform (Oldest)',
    'PPPoE Username (A-Z)',
    'PPPoE Username (Z-A)',
    'Model (A-Z)',
    'Model (Z-A)',
  ];
  final List<String> _statusOptions = ['Semua', 'Online', 'Idle', 'Offline'];
  final List<String> _rxOptions = [
    'Semua',
    'RX Bagus',
    'RX Lumayan',
    'RX Kritis'
  ];

  @override
  void initState() {
    super.initState();
    _loadCachedData();
    _refreshDataInBackground();

    // Timer untuk update "Baru saja" per detik
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        // Force rebuild untuk update "Last Inform" time
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _updateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedData() async {
    try {
      final devices = await GenieACSConfigService.getCachedDeviceData();
      if (mounted) {
        setState(() {
          _devices = devices;
        });
      }
    } catch (e) {
      print('[GenieACS] Error loading cached data: $e');
    }
  }

  Future<void> _refreshDataInBackground() async {
    // Check if configured
    final isConfigured = await GenieACSConfigService.isConfigured();
    if (!isConfigured) return;

    setState(() => _isLoading = true);

    try {
      final url = await GenieACSConfigService.getGenieACSUrl();
      final username = await GenieACSConfigService.getGenieACSUsername();
      final password = await GenieACSConfigService.getGenieACSPassword();

      if (url != null && username != null && password != null) {
        _service = GenieACSService(
          baseUrl: url,
          username: username,
          password: password,
        );

        print('[GenieACS] Refreshing data...');
        final devices = await _service!.getDevices();

        // Cache the data
        await GenieACSConfigService.cacheDeviceData(devices);

        if (mounted) {
          setState(() {
            _devices = devices;
            _isLoading = false;
          });
        }
        print('[GenieACS] Data refreshed. ${devices.length} devices loaded.');
      }
    } catch (e) {
      print('[GenieACS] Refresh error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _isRefreshing = true);
    await _refreshDataInBackground();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data diperbarui'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedDevices() {
    final lowercaseQuery = _searchController.text.toLowerCase();

    // First filter by search query
    List<Map<String, dynamic>> filtered = _devices.where((device) {
      if (lowercaseQuery.isEmpty) return true;

      final pppoeUsername =
          DeviceInfoExtractor.getPPPoEUsername(device).toLowerCase();
      final deviceId = DeviceInfoExtractor.getDeviceId(device).toLowerCase();
      final pppoeIP = DeviceInfoExtractor.getPPPoEIP(device).toLowerCase();
      final serialNumber =
          DeviceInfoExtractor.getSerialNumber(device).toLowerCase();

      return pppoeUsername.contains(lowercaseQuery) ||
          pppoeIP.contains(lowercaseQuery) ||
          deviceId.contains(lowercaseQuery) ||
          serialNumber.contains(lowercaseQuery);
    }).toList();

    // Then filter by status
    if (_statusFilter != 'Semua') {
      filtered = filtered.where((device) {
        final status = DeviceInfoExtractor.getConnectionStatus(device);
        return status.toLowerCase() == _statusFilter.toLowerCase();
      }).toList();
    }

    // Then filter by RX Power
    if (_rxFilter != 'Semua') {
      filtered = filtered.where((device) {
        final rxPowerStr = DeviceInfoExtractor.getRXPower(device);
        if (rxPowerStr == '-') return false;

        try {
          final rxPower = double.parse(rxPowerStr);
          switch (_rxFilter) {
            case 'RX Bagus':
              return rxPower >= -20;
            case 'RX Lumayan':
              return rxPower >= -25 && rxPower < -20;
            case 'RX Kritis':
              return rxPower >= -30 && rxPower < -25;
            default:
              return true;
          }
        } catch (e) {
          return false;
        }
      }).toList();
    }

    // Then sort
    filtered.sort((a, b) {
      switch (_sortOption) {
        case 'Last Inform (Newest)':
          final aDate =
              DateTime.tryParse(a['_lastInform'] ?? '') ?? DateTime(1970);
          final bDate =
              DateTime.tryParse(b['_lastInform'] ?? '') ?? DateTime(1970);
          return bDate.compareTo(aDate);
        case 'Last Inform (Oldest)':
          final aDate =
              DateTime.tryParse(a['_lastInform'] ?? '') ?? DateTime(1970);
          final bDate =
              DateTime.tryParse(b['_lastInform'] ?? '') ?? DateTime(1970);
          return aDate.compareTo(bDate);
        case 'PPPoE Username (A-Z)':
          return DeviceInfoExtractor.getPPPoEUsername(a)
              .compareTo(DeviceInfoExtractor.getPPPoEUsername(b));
        case 'PPPoE Username (Z-A)':
          return DeviceInfoExtractor.getPPPoEUsername(b)
              .compareTo(DeviceInfoExtractor.getPPPoEUsername(a));
        case 'Model (A-Z)':
          return DeviceInfoExtractor.getModel(a)
              .compareTo(DeviceInfoExtractor.getModel(b));
        case 'Model (Z-A)':
          return DeviceInfoExtractor.getModel(b)
              .compareTo(DeviceInfoExtractor.getModel(a));
        default:
          return 0;
      }
    });

    return filtered;
  }

  void _showFilterDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text('Filter',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  )),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              value: _sortOption,
              items: _sortOptions
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => _sortOption = v!),
              decoration: InputDecoration(
                labelText: 'Urutkan',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.blue.shade300 : Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              value: _statusFilter,
              items: _statusOptions
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => _statusFilter = v!),
              decoration: InputDecoration(
                labelText: 'Status Koneksi',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.blue.shade300 : Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              dropdownColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              value: _rxFilter,
              items: _rxOptions
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      )))
                  .toList(),
              onChanged: (v) => setState(() => _rxFilter = v!),
              decoration: InputDecoration(
                labelText: 'Filter RX Power',
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.blue.shade300 : Colors.blue,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.blue.shade700 : Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Selesai'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(Map<String, dynamic> device) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.lock, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ganti Password',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device: ${DeviceInfoExtractor.getPPPoEUsername(device)}',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                hintText: 'Masukkan password baru',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password tidak boleh kosong'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Mengganti password...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );

              final success = await _service!.changePassword(
                DeviceInfoExtractor.getDeviceId(device),
                passwordController.text,
              );

              if (mounted) {
                Navigator.pop(context); // Close loading dialog

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Password berhasil diganti'
                          : 'Gagal mengganti password',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );

                if (success) {
                  // Refresh data after password change
                  await _manualRefresh();
                }
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Ganti'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeviceDetails(Map<String, dynamic> device) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.devices, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Details',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DeviceInfoExtractor.getPPPoEUsername(device),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Virtual Parameters section (moved to top)
                    _buildDetailSection(
                      'Virtual Parameters',
                      DeviceInfoExtractor.getVirtualParameters(device)
                          .entries
                          .map((entry) {
                        final displayName =
                            _formatVirtualParameterName(entry.key);
                        return _buildDetailRow(displayName, entry.value);
                      }).toList(),
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Device Information',
                      [
                        _buildDetailRow('Device ID',
                            DeviceInfoExtractor.getDeviceId(device)),
                        _buildDetailRow('Serial Number',
                            DeviceInfoExtractor.getSerialNumber(device)),
                        _buildDetailRow('Manufacturer',
                            DeviceInfoExtractor.getManufacturer(device)),
                        _buildDetailRow(
                            'Model', DeviceInfoExtractor.getModel(device)),
                        _buildDetailRow('Product Class',
                            DeviceInfoExtractor.getProductClass(device)),
                        _buildDetailRow(
                            'OUI', DeviceInfoExtractor.getOUI(device)),
                      ],
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Network',
                      [
                        _buildDetailRow('Status',
                            DeviceInfoExtractor.getConnectionStatus(device)),
                        _buildDetailRow('Last Inform',
                            DeviceInfoExtractor.getLastInform(device)),
                        _buildDetailRow('IP Address',
                            DeviceInfoExtractor.getIPAddress(device) ?? '-'),
                        _buildDetailRow(
                            'PPPoE IP', DeviceInfoExtractor.getPPPoEIP(device)),
                        _buildDetailRow('PPPoE MAC',
                            DeviceInfoExtractor.getPPPoEMac(device)),
                        _buildDetailRow(
                            'SSID', DeviceInfoExtractor.getSSID(device)),
                        _buildDetailRow('MAC Address',
                            DeviceInfoExtractor.getMACAddress(device)),
                      ],
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Status & Performance',
                      [
                        _buildDetailRow('RX Power',
                            DeviceInfoExtractor.getRXPowerWithStatus(device)),
                        _buildDetailRow(
                            'Temperature',
                            DeviceInfoExtractor.getTemperatureWithStatus(
                                device)),
                        _buildDetailRow('Active Devices',
                            DeviceInfoExtractor.getActiveWithStatus(device)),
                        _buildDetailRow('Device Uptime',
                            DeviceInfoExtractor.getDeviceUptime(device)),
                        _buildDetailRow('PPPoE Uptime',
                            DeviceInfoExtractor.getPPPoEUptime(device)),
                        _buildDetailRow(
                            'PON Mode', DeviceInfoExtractor.getPONMode(device)),
                      ],
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Firmware',
                      [
                        _buildDetailRow(
                            'Firmware',
                            DeviceInfoExtractor.getFirmwareVersion(device) ??
                                '-'),
                        _buildDetailRow(
                            'Hardware',
                            DeviceInfoExtractor.getHardwareVersion(device) ??
                                '-'),
                      ],
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailSection(
                      'Timing',
                      [
                        _buildDetailRow('Registered',
                            DeviceInfoExtractor.getRegisteredTime(device)),
                        _buildDetailRow('Last Communication',
                            DeviceInfoExtractor.getLastCommunication(device)),
                      ],
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    if (DeviceInfoExtractor.getTags(device).isNotEmpty)
                      _buildDetailSection(
                        'Tags',
                        [
                          Wrap(
                            spacing: 8,
                            children: DeviceInfoExtractor.getTags(device)
                                .map((tag) => Chip(
                                      label: Text(tag),
                                      backgroundColor: Colors.blue.shade50,
                                    ))
                                .toList(),
                          ),
                        ],
                        isDark,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children, bool isDark) {
    // Determine section color based on title
    Color sectionColor;
    IconData sectionIcon;
    switch (title) {
      case 'Virtual Parameters':
        sectionColor = Colors.purple;
        sectionIcon = Icons.tune;
        break;
      case 'Device Information':
        sectionColor = Colors.blue;
        sectionIcon = Icons.info;
        break;
      case 'Network':
        sectionColor = Colors.cyan;
        sectionIcon = Icons.network_check;
        break;
      case 'Status & Performance':
        sectionColor = Colors.orange;
        sectionIcon = Icons.speed;
        break;
      case 'Firmware':
        sectionColor = Colors.teal;
        sectionIcon = Icons.memory;
        break;
      case 'Timing':
        sectionColor = Colors.indigo;
        sectionIcon = Icons.access_time;
        break;
      case 'Tags':
        sectionColor = Colors.green;
        sectionIcon = Icons.label;
        break;
      default:
        sectionColor = Colors.grey;
        sectionIcon = Icons.category;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: sectionColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              sectionColor.withOpacity(0.05),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: sectionColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(sectionIcon, color: sectionColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get icon for label
    IconData icon;
    Color iconColor;
    switch (label) {
      case 'Device ID':
        icon = Icons.qr_code;
        iconColor = Colors.blue;
        break;
      case 'Serial Number':
        icon = Icons.confirmation_number;
        iconColor = Colors.orange;
        break;
      case 'Manufacturer':
        icon = Icons.business;
        iconColor = Colors.purple;
        break;
      case 'Model':
        icon = Icons.devices;
        iconColor = Colors.indigo;
        break;
      case 'Product Class':
        icon = Icons.inventory_2;
        iconColor = Colors.brown;
        break;
      case 'OUI':
        icon = Icons.fingerprint;
        iconColor = Colors.pink;
        break;
      case 'Status':
        icon = Icons.power_settings_new;
        iconColor = _getStatusColorForValue(value, isDark);
        break;
      case 'Last Inform':
        icon = Icons.access_time;
        iconColor = Colors.cyan;
        break;
      case 'IP Address':
        icon = Icons.language;
        iconColor = Colors.blue;
        break;
      case 'PPPoE IP':
        icon = Icons.cloud;
        iconColor = Colors.blue.shade700;
        break;
      case 'PPPoE MAC':
        icon = Icons.router;
        iconColor = Colors.green.shade700;
        break;
      case 'SSID':
        icon = Icons.wifi;
        iconColor = Colors.purple;
        break;
      case 'MAC Address':
        icon = Icons.network_cell;
        iconColor = Colors.teal;
        break;
      case 'RX Power':
        icon = Icons.signal_cellular_alt;
        iconColor = _getRXPowerColor(value);
        break;
      case 'Temperature':
        icon = Icons.thermostat;
        iconColor = _getTemperatureColor(value);
        break;
      case 'Active Devices':
        icon = Icons.people;
        iconColor = Colors.green;
        break;
      case 'Device Uptime':
        icon = Icons.timer;
        iconColor = Colors.indigo;
        break;
      case 'PPPoE Uptime':
        icon = Icons.history;
        iconColor = Colors.deepPurple;
        break;
      case 'PON Mode':
        icon = Icons.cable;
        iconColor = Colors.amber;
        break;
      case 'Firmware':
        icon = Icons.update;
        iconColor = Colors.teal;
        break;
      case 'Hardware':
        icon = Icons.build;
        iconColor = Colors.grey;
        break;
      case 'Registered':
        icon = Icons.calendar_today;
        iconColor = Colors.orange;
        break;
      case 'Last Communication':
        icon = Icons.chat_bubble_outline;
        iconColor = Colors.cyan;
        break;
      default:
        icon = Icons.label_outline;
        iconColor = Colors.grey;
    }

    // Determine if value needs badge decoration
    final hasStatus = value.toLowerCase().contains('bagus') ||
        value.toLowerCase().contains('lumayan') ||
        value.toLowerCase().contains('kritis') ||
        value.toLowerCase().contains('online') ||
        value.toLowerCase().contains('offline') ||
        value.toLowerCase().contains('idle') ||
        value.toLowerCase().contains('anget') ||
        value.toLowerCase().contains('adem') ||
        value.toLowerCase().contains('panas') ||
        value.toLowerCase().contains('normal') ||
        value.toLowerCase().contains('medium') ||
        value.toLowerCase().contains('over') ||
        value.toLowerCase().contains('empty');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: hasStatus && value != '-'
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColorForValue(value, isDark)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _getStatusColorForValue(value, isDark)
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        color: _getStatusColorForValue(value, isDark),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColorForValue(String value, bool isDark) {
    final lowerValue = value.toLowerCase();
    if (lowerValue.contains('bagus') ||
        lowerValue.contains('normal') ||
        lowerValue.contains('online')) {
      return Colors.green;
    } else if (lowerValue.contains('lumayan') ||
        lowerValue.contains('medium')) {
      return Colors.orange;
    } else if (lowerValue.contains('kritis') ||
        lowerValue.contains('offline')) {
      return Colors.red;
    } else if (lowerValue.contains('adem')) {
      return Colors.blue;
    } else if (lowerValue.contains('anget')) {
      return Colors.orange;
    } else if (lowerValue.contains('panas')) {
      return Colors.red;
    } else if (lowerValue.contains('over')) {
      return Colors.red;
    } else if (lowerValue.contains('empty')) {
      return Colors.grey;
    }
    return Colors.grey;
  }

  Color _getRXPowerColor(String value) {
    if (value.toLowerCase().contains('bagus')) return Colors.green;
    if (value.toLowerCase().contains('lumayan')) return Colors.orange;
    if (value.toLowerCase().contains('kritis')) return Colors.red;
    return Colors.grey;
  }

  Color _getTemperatureColor(String value) {
    if (value.toLowerCase().contains('adem')) return Colors.blue;
    if (value.toLowerCase().contains('anget')) return Colors.orange;
    if (value.toLowerCase().contains('panas')) return Colors.red;
    return Colors.grey;
  }

  String _formatVirtualParameterName(String key) {
    // Map technical names to user-friendly names
    final nameMap = {
      'ipTR069': 'IP TR-069',
      'ponMac': 'PON MAC',
      'rxPower': 'RX Power',
      'wlanPassword': 'WLAN Password',
      'activedevices': 'Active Devices',
      'getSerialNumber': 'Serial Number',
      'getdeviceuptime': 'Device Uptime',
      'getponmode': 'PON Mode',
      'getpppuptime': 'PPPoE Uptime',
      'gettemp': 'Temperature',
      'pppoeIP': 'PPPoE IP',
      'pppoeMac': 'PPPoE MAC',
      'pppoePassword': 'PPPoE Password',
      'pppoeUsername': 'PPPoE Username',
      'superPassword': 'Super Password',
      'getIPTR069': 'IP TR-069',
      'getPonMac': 'PON MAC',
      'getTemperature': 'Temperature',
      'getDeviceUptime': 'Device Uptime',
      'getPPPoEUptime': 'PPPoE Uptime',
      'getPONMode': 'PON Mode',
      'getPPPoEMac': 'PPPoE MAC',
      'getActiveDevices': 'Active Devices',
      'getRXPower': 'RX Power',
      'getPPPoEIP': 'PPPoE IP',
      'getPPPoEUsername': 'PPPoE Username',
    };

    // Check if direct mapping exists
    if (nameMap.containsKey(key)) {
      return nameMap[key]!;
    }

    // Otherwise, format by removing 'get' prefix and converting camelCase to Title Case
    String formatted = key.replaceAll(RegExp(r'^get'), '');
    formatted = formatted.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    );
    formatted = formatted.trim();

    // Convert first letter to uppercase
    if (formatted.isNotEmpty) {
      formatted = formatted[0].toUpperCase() + formatted.substring(1);
    }

    return formatted.isEmpty ? key : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final filteredDevices = _getFilteredAndSortedDevices();

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'GenieACS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isRefreshing ? null : _manualRefresh,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.pushNamed(context, '/api-config');
              },
              tooltip: 'Pengaturan',
            ),
          ],
        ),
        body: _isLoading && _devices.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_devices.isEmpty)
                            Card(
                              elevation: 2,
                              color: isDark
                                  ? const Color(0xFF1E1E1E)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_off,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Belum Dikonfigurasi',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Silakan konfigurasi GenieACS di Settings',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            // Search and Filter Bar
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      // Cancel previous debounce timer
                                      _searchDebounce?.cancel();

                                      // Create new timer to wait for user to stop typing
                                      _searchDebounce = Timer(
                                          const Duration(milliseconds: 500),
                                          () {
                                        setState(
                                            () {}); // Rebuild to update filtered list
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Cari...',
                                      prefixIcon: const Icon(Icons.search),
                                      suffixIcon:
                                          _searchController.text.isNotEmpty
                                              ? IconButton(
                                                  icon: const Icon(Icons.clear),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() {});
                                                  },
                                                )
                                              : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: isDark
                                          ? Colors.grey.shade900
                                          : Colors.grey.shade100,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    Icons.filter_list,
                                    color: _statusFilter != 'Semua' ||
                                            _sortOption !=
                                                'Last Inform (Newest)' ||
                                            _rxFilter != 'Semua'
                                        ? (isDark
                                            ? Colors.blue.shade300
                                            : Colors.blue.shade800)
                                        : (isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade600),
                                  ),
                                  onPressed: _showFilterDialog,
                                  tooltip: 'Filter',
                                  style: IconButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.grey.shade900
                                        : Colors.grey.shade100,
                                    padding: const EdgeInsets.all(12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Devices List
                            if (_isLoading)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (filteredDevices.isEmpty)
                              Card(
                                elevation: 2,
                                color: isDark
                                    ? const Color(0xFF1E1E1E)
                                    : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black38,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Tidak ada device ditemukan',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              ...filteredDevices.map((device) {
                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: isDark
                                      ? const Color(0xFF1E1E1E)
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () =>
                                              _showDeviceDetails(device),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                        color: _getStatusColor(
                                                                device)
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                      ),
                                                      child: Icon(
                                                        Icons.router,
                                                        color: _getStatusColor(
                                                            device),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            DeviceInfoExtractor
                                                                .getPPPoEUsername(
                                                                    device),
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: isDark
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .black87,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                              height: 2),
                                                          Text(
                                                            DeviceInfoExtractor
                                                                        .getPPPoEIP(
                                                                            device) !=
                                                                    '-'
                                                                ? DeviceInfoExtractor
                                                                    .getPPPoEIP(
                                                                        device)
                                                                : DeviceInfoExtractor
                                                                    .getModel(
                                                                        device),
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: isDark
                                                                  ? Colors
                                                                      .white70
                                                                  : Colors
                                                                      .black54,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.wifi_tethering,
                                                      size: 14,
                                                      color: isDark
                                                          ? Colors
                                                              .orange.shade300
                                                          : Colors
                                                              .orange.shade700,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'RX: ${DeviceInfoExtractor.getRXPower(device)} dBm',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: isDark
                                                            ? Colors
                                                                .orange.shade300
                                                            : Colors.orange
                                                                .shade700,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Icon(
                                                      Icons.info_outline,
                                                      size: 14,
                                                      color: isDark
                                                          ? Colors.white54
                                                          : Colors.black54,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        DeviceInfoExtractor
                                                            .getLastInform(
                                                                device),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black54,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (DeviceInfoExtractor.getTags(
                                                        device)
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 4,
                                                    children:
                                                        DeviceInfoExtractor
                                                                .getTags(device)
                                                            .take(3)
                                                            .map(
                                                                (tag) =>
                                                                    Container(
                                                                      padding:
                                                                          const EdgeInsets
                                                                              .symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Colors
                                                                            .blue
                                                                            .shade50,
                                                                        borderRadius:
                                                                            BorderRadius.circular(4),
                                                                      ),
                                                                      child:
                                                                          Text(
                                                                        tag,
                                                                        style:
                                                                            TextStyle(
                                                                          fontSize:
                                                                              10,
                                                                          color: Colors
                                                                              .blue
                                                                              .shade700,
                                                                        ),
                                                                      ),
                                                                    ))
                                                            .toList(),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _showChangePasswordDialog(device),
                                        tooltip: 'Ganti Password',
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_devices.isEmpty) return const SizedBox.shrink();

    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final filteredDevices = _getFilteredAndSortedDevices();

    final filteredTotal = filteredDevices.length;
    final totalDevices = _devices.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.router,
                color: isDark ? Colors.white70 : Colors.black54, size: 18),
            const SizedBox(width: 6),
            Text(
              '$filteredTotal Total ACS Devices',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (filteredTotal != totalDevices) ...[
              Text(
                ' (of $totalDevices)',
                style: TextStyle(
                  color: isDark ? Colors.white54 : Colors.black38,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(Map<String, dynamic> device) {
    final status = DeviceInfoExtractor.getConnectionStatus(device);
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'idle':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
