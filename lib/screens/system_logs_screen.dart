import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/router_session_provider.dart';
import '../services/log_service.dart';
import '../widgets/gradient_container.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  final List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoading &&
        _hasMore) {
      _loadLogs();
    }
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      if (refresh) {
        _logs.clear();
        _offset = 0;
        _hasMore = true;
      }
    });

    try {
      final session = context.read<RouterSessionProvider>();
      final routerId = session.routerId;

      if (routerId == null) {
        throw Exception('Router ID not found');
      }

      final newLogs = await LogService.getSystemLogs(
        routerId: routerId,
        limit: _limit,
        offset: _offset,
      );

      setState(() {
        _logs.addAll(newLogs);
        _offset += newLogs.length;
        if (newLogs.length < _limit) {
          _hasMore = false;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat log: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Color _getActionColor(String action) {
    if (action.contains('DELETE')) return Colors.redAccent;
    if (action.contains('ADD')) return Colors.green;
    if (action.contains('EDIT') || action.contains('UPDATE'))
      return Colors.orange;
    if (action.contains('LOGIN') || action.contains('LOGOUT'))
      return Colors.blueAccent;
    return Colors.grey;
  }

  IconData _getActionIcon(String action) {
    if (action.contains('DELETE')) return Icons.delete_rounded;
    if (action.contains('ADD')) return Icons.add_circle_rounded;
    if (action.contains('EDIT') || action.contains('UPDATE'))
      return Icons.edit_rounded;
    if (action.contains('LOGIN')) return Icons.login_rounded;
    if (action.contains('LOGOUT')) return Icons.logout_rounded;
    return Icons.info_rounded;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        const GradientContainer(child: SizedBox.expand()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('System Logs'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back,
                  color: isDark ? Colors.white : Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            titleTextStyle: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () => _loadLogs(refresh: true),
            child: _logs.isEmpty && !_isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history,
                            size: 64,
                            color: isDark ? Colors.white24 : Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada aktivitas tercatat',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _logs.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      final log = _logs[index];
                      final action = log['action'] ?? 'UNKNOWN';
                      final username = log['username'] ?? 'System';
                      final details = log['details'] ?? '';
                      final timestamp = log['timestamp'] ?? log['created_at'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: _getActionColor(action)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getActionIcon(action),
                                      color: _getActionColor(action),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          action,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _getActionColor(action),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(timestamp),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white54
                                                : Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey[800]
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.person_outline,
                                          size: 12,
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          username,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (details.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Divider(
                                  height: 1,
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  details,
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[800],
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
