import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/mikrotik_provider.dart';
import '../widgets/gradient_container.dart';

class TrafficScreen extends StatefulWidget {
  const TrafficScreen({super.key});

  @override
  State<TrafficScreen> createState() => _TrafficScreenState();
}

class _TrafficScreenState extends State<TrafficScreen> {
  Timer? _timer;
  Map<String, dynamic>? _trafficData;
  String? _selectedInterfaceId;
  List<Map<String, dynamic>> _interfaces = [];
  Map<String, dynamic>? _selectedInterface;
  final TextEditingController _searchController = TextEditingController();

  // Graph data
  final List<FlSpot> _txPoints = [];
  final List<FlSpot> _rxPoints = [];
  double _timeCounter = 0;
  static const int _maxPoints = 20;

  @override
  void initState() {
    super.initState();
    _loadInterfaces();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showInterfaceSelector() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String searchQuery = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredInterfaces = _interfaces.where((interface) {
              final name = (interface['name'] ?? '').toString().toLowerCase();
              return name.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              title: Text(
                'Pilih Interface',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Field
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari interface...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    // Interface List
                    Flexible(
                      child: filteredInterfaces.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada interface ditemukan',
                                style: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredInterfaces.length,
                              itemBuilder: (context, index) {
                                final interface = filteredInterfaces[index];
                                final isSelected =
                                    interface['.id'] == _selectedInterfaceId;
                                return ListTile(
                                  selected: isSelected,
                                  selectedTileColor: isDark
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.blue.withValues(alpha: 0.1),
                                  title: Text(
                                    interface['name'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: interface['type'] != null
                                      ? Text(
                                          interface['type'],
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                            fontSize: 12,
                                          ),
                                        )
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.blue,
                                        )
                                      : null,
                                  onTap: () {
                                    this.setState(() {
                                      _selectedInterfaceId = interface['.id'];
                                      _selectedInterface = interface;
                                      _startPolling();
                                    });
                                    _searchController.clear();
                                    Navigator.of(context).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Batal',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _loadInterfaces() async {
    final provider = Provider.of<MikrotikProvider>(context, listen: false);
    try {
      final interfaces = await provider.service.getInterface();
      if (!mounted) {
        return;
      }
      setState(() {
        _interfaces = interfaces;
        if (interfaces.isNotEmpty) {
          _selectedInterfaceId = interfaces.first['.id'];
          _selectedInterface = interfaces.first;
          _startPolling();
        }
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat interface: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _resetGraph();
    _fetchTrafficData();
    // Polling every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _fetchTrafficData();
    });
  }

  void _resetGraph() {
    _txPoints.clear();
    _rxPoints.clear();
    _timeCounter = 0;
    // Initialize with zeros
    for (int i = 0; i < _maxPoints; i++) {
      _txPoints.add(FlSpot(i.toDouble(), 0));
      _rxPoints.add(FlSpot(i.toDouble(), 0));
    }
    _timeCounter = _maxPoints.toDouble();
  }

  Future<void> _fetchTrafficData() async {
    if (_selectedInterfaceId == null) {
      return;
    }

    final provider = Provider.of<MikrotikProvider>(context, listen: false);
    try {
      final trafficData =
          await provider.service.getTraffic(_selectedInterfaceId!);
      if (!mounted) {
        return;
      }

      setState(() {
        _trafficData = trafficData;
        _updateGraphData(trafficData);
      });
    } catch (e) {
      // Silent error for polling to avoid spamming snackbars
      debugPrint('Error fetching traffic data: $e');
    }
  }

  void _updateGraphData(Map<String, dynamic> data) {
    final txRate = (data['tx-rate'] as num?)?.toDouble() ?? 0.0;
    final rxRate = (data['rx-rate'] as num?)?.toDouble() ?? 0.0;

    _txPoints.add(FlSpot(_timeCounter, txRate));
    _rxPoints.add(FlSpot(_timeCounter, rxRate));
    _timeCounter++;

    if (_txPoints.length > _maxPoints) {
      _txPoints.removeAt(0);
      _rxPoints.removeAt(0);
    }
  }

  String _formatRate(double rate) {
    // API already returns rate in Mbps
    if (rate < 1) {
      // Less than 1 Mbps, show in Kbps
      return (rate * 1000).toStringAsFixed(1);
    }
    // 1 Mbps or more, show in Mbps
    return rate.toStringAsFixed(1);
  }

  String _formatRateUnit(double rate) {
    if (rate < 1) {
      return 'Kbps';
    }
    return 'Mbps';
  }

  String _formatPacketRate(dynamic rate) {
    return '$rate p/s';
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null) {
      return '-';
    }
    int b = int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) {
      return '$b B';
    }
    if (b < 1024 * 1024) {
      return '${(b / 1024).toStringAsFixed(1)} KB';
    }
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatPackets(dynamic packets) {
    if (packets == null) {
      return '-';
    }
    return packets.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Monitor Trafik'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Main Card containing all content
                Card(
                  elevation: 0,
                  color: isDark
                      ? const Color(0xFF1E1E1E).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Interface Selector with Search
                        GestureDetector(
                          onTap: _showInterfaceSelector,
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedInterface != null
                                        ? _selectedInterface!['name'] ??
                                            'Unknown'
                                        : 'Pilih Interface',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: _selectedInterface != null
                                          ? (isDark
                                              ? Colors.white
                                              : Colors.black87)
                                          : (isDark
                                              ? Colors.white70
                                              : Colors.black54),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_trafficData != null &&
                            _selectedInterface != null) ...[
                          const SizedBox(height: 16),
                          // Status Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _selectedInterface!['running'] == "true"
                                  ? (isDark
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.green.withValues(alpha: 0.1))
                                  : (isDark
                                      ? Colors.red.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.1)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 12,
                                  color:
                                      _selectedInterface!['running'] == "true"
                                          ? Colors.green
                                          : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedInterface!['running'] == "true"
                                      ? "Berjalan"
                                      : "Berhenti",
                                  style: TextStyle(
                                    color:
                                        _selectedInterface!['running'] == "true"
                                            ? (isDark
                                                ? Colors.green.shade300
                                                : Colors.green)
                                            : (isDark
                                                ? Colors.red.shade300
                                                : Colors.red),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Traffic Graph
                          SizedBox(
                            height: 200,
                            child: LineChart(
                              LineChartData(
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.black12,
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  rightTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          _formatRate(value),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.black54,
                                            fontSize: 10,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(show: false),
                                minX: _timeCounter - _maxPoints,
                                maxX: _timeCounter,
                                minY: 0,
                                lineBarsData: [
                                  // RX Line (Blue)
                                  LineChartBarData(
                                    spots: _rxPoints,
                                    isCurved: true,
                                    color: Colors.blue,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.blue.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  // TX Line (Orange)
                                  LineChartBarData(
                                    spots: _txPoints,
                                    isCurved: true,
                                    color: Colors.deepOrange,
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: true,
                                      color: Colors.deepOrange
                                          .withValues(alpha: 0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Traffic Rate Display
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildRateInfo(
                                    'TX Rate',
                                    _formatRate(_trafficData!['tx-rate']),
                                    _formatRateUnit(_trafficData!['tx-rate']),
                                    _formatPacketRate(
                                        _trafficData!['tx-packet-rate']),
                                    Colors.deepOrange,
                                    isDark: isDark,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: VerticalDivider(
                                    color: isDark
                                        ? Colors.grey[700]
                                        : Colors.grey[300],
                                    thickness: 1,
                                    indent: 10,
                                    endIndent: 10,
                                  ),
                                ),
                                Expanded(
                                  child: _buildRateInfo(
                                    'RX Rate',
                                    _formatRate(_trafficData!['rx-rate']),
                                    _formatRateUnit(_trafficData!['rx-rate']),
                                    _formatPacketRate(
                                        _trafficData!['rx-packet-rate']),
                                    Colors.blue,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Divider(height: 1),
                          ),
                          // Interface Details
                          Text(
                            'Detail Interface',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                              'Nama', _selectedInterface!['name'] ?? '-',
                              isDark: isDark),
                          _buildDetailRow(
                              'Tipe', _selectedInterface!['type'] ?? '-',
                              isDark: isDark),
                          _buildDetailRow('MAC Address',
                              _selectedInterface!['mac-address'] ?? '-',
                              isDark: isDark),
                          _buildDetailRow(
                              'MTU', _selectedInterface!['mtu'] ?? '-',
                              isDark: isDark),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),
                          // Total Traffic
                          Text(
                            'Total Trafik',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('Total TX',
                              _formatBytes(_trafficData!['total-tx-byte']),
                              isTotal: true, isDark: isDark),
                          _buildDetailRow('Total RX',
                              _formatBytes(_trafficData!['total-rx-byte']),
                              isTotal: true, isDark: isDark),
                          _buildDetailRow('TX Packets',
                              _formatPackets(_trafficData!['total-tx-packet']),
                              isDark: isDark),
                          _buildDetailRow('RX Packets',
                              _formatPackets(_trafficData!['total-rx-packet']),
                              isDark: isDark),
                        ] else ...[
                          const SizedBox(height: 100),
                          const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRateInfo(String label, String rate, String unit,
      String packetRate, MaterialColor color,
      {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? color.shade300 : color,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                rate,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          packetRate,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool isTotal = false, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
