import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/mikrotik_provider.dart';
import '../providers/router_session_provider.dart';
import '../widgets/gradient_container.dart';

class DatabaseSyncScreen extends StatefulWidget {
  const DatabaseSyncScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseSyncScreen> createState() => _DatabaseSyncScreenState();
}

class _DatabaseSyncScreenState extends State<DatabaseSyncScreen> {
  bool _isLoading = true;
  String? _error;

  // Data from database
  List<Map<String, dynamic>> _dbUsers = [];

  // Data from PPP
  List<Map<String, dynamic>> _pppUsers = [];

  // Comparison results
  List<Map<String, dynamic>> _onlyInDatabase = [];
  List<Map<String, dynamic>> _onlyInPPP = [];
  List<Map<String, dynamic>> _synced = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selected category
  int _selectedCategory = 0; // 0: Only in DB, 1: Only in PPP, 2: Synced

  @override
  void initState() {
    super.initState();
    _loadAndCompareData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAndCompareData() async {
    if (!mounted) return;

    final routerSession =
        Provider.of<RouterSessionProvider>(context, listen: false);
    final routerId = routerSession.routerId;

    if (routerId == null) {
      setState(() {
        _isLoading = false;
        _error = 'Router ID tidak ditemukan. Silakan login ulang.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch data from database
      final dbResponse = await ApiService.getAllUsers(routerId: routerId);
      if (dbResponse['success'] != true) {
        throw Exception(
            dbResponse['error'] ?? 'Gagal memuat data dari database');
      }
      _dbUsers = List<Map<String, dynamic>>.from(dbResponse['users'] ?? []);

      // Fetch data from PPP
      if (!mounted) return;
      final mikrotikProvider =
          Provider.of<MikrotikProvider>(context, listen: false);
      await mikrotikProvider.fetchPPPSecrets(forceRefresh: true);
      _pppUsers = mikrotikProvider.pppSecrets;

      // Compare data
      _compareData();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat data: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _compareData() {
    // Create sets of usernames for fast lookup
    final dbUsernames = _dbUsers
        .where((u) => (u['username']?.toString().trim().isNotEmpty ?? false))
        .map((u) => u['username'].toString())
        .toSet();

    final pppUsernames = _pppUsers
        .where((u) => (u['name']?.toString().trim().isNotEmpty ?? false))
        .map((u) => u['name'].toString())
        .toSet();

    // Find users only in database (not in PPP)
    _onlyInDatabase = _dbUsers.where((user) {
      final username = user['username']?.toString() ?? '';
      return username.isNotEmpty && !pppUsernames.contains(username);
    }).toList();

    // Find users only in PPP (not in database)
    _onlyInPPP = _pppUsers.where((user) {
      final username = user['name']?.toString() ?? '';
      return username.isNotEmpty && !dbUsernames.contains(username);
    }).toList();

    // Find synced users (exist in both)
    _synced = _dbUsers.where((user) {
      final username = user['username']?.toString() ?? '';
      return username.isNotEmpty && pppUsernames.contains(username);
    }).toList();

    print('[DatabaseSync] Total in DB: ${_dbUsers.length}');
    print('[DatabaseSync] Total in PPP: ${_pppUsers.length}');
    print('[DatabaseSync] Only in DB: ${_onlyInDatabase.length}');
    print('[DatabaseSync] Only in PPP: ${_onlyInPPP.length}');
    print('[DatabaseSync] Synced: ${_synced.length}');
  }

  List<Map<String, dynamic>> _getFilteredUsers() {
    List<Map<String, dynamic>> users;

    switch (_selectedCategory) {
      case 0:
        users = _onlyInDatabase;
        break;
      case 1:
        users = _onlyInPPP;
        break;
      case 2:
        users = _synced;
        break;
      default:
        users = [];
    }

    if (_searchQuery.isEmpty) {
      return users;
    }

    // Apply search filter
    return users.where((user) {
      final username =
          (_selectedCategory == 1 ? user['name'] : user['username'])
                  ?.toString()
                  .toLowerCase() ??
              '';
      final profile =
          (_selectedCategory == 1 ? user['profile'] : user['profile'])
                  ?.toString()
                  .toLowerCase() ??
              '';
      final query = _searchQuery.toLowerCase();

      return username.contains(query) || profile.contains(query);
    }).toList();
  }

  Future<void> _deleteUserFromDatabase(Map<String, dynamic> user) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus dari Database',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Yakin ingin menghapus user "${user['username']}" dari database?\n\nUser ini tidak ada di PPP MikroTik.',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style:
                  TextStyle(color: isDark ? Colors.blue.shade300 : Colors.blue),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final routerSession =
            Provider.of<RouterSessionProvider>(context, listen: false);
        final routerId = routerSession.routerId;

        if (routerId == null) {
          throw Exception('Router ID tidak ditemukan');
        }

        await ApiService.deleteUser(
          routerId: routerId,
          username: user['username'] as String,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User berhasil dihapus dari database'),
              backgroundColor: Colors.green,
            ),
          );

          // Reload data
          _loadAndCompareData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus user: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Database Sync Check',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh',
              onPressed: _isLoading ? null : _loadAndCompareData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAndCompareData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Summary Cards
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _summaryCard(
                                    'Database',
                                    _dbUsers.length,
                                    Icons.storage,
                                    Colors.blue,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _summaryCard(
                                    'PPP',
                                    _pppUsers.length,
                                    Icons.router,
                                    Colors.green,
                                    isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _summaryCard(
                                    'Synced',
                                    _synced.length,
                                    Icons.check_circle,
                                    Colors.teal,
                                    isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _summaryCard(
                                    'Mismatch',
                                    _onlyInDatabase.length + _onlyInPPP.length,
                                    Icons.warning,
                                    Colors.orange,
                                    isDark,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Category Tabs
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _categoryTab(
                                'Only in DB',
                                _onlyInDatabase.length,
                                0,
                                Colors.red,
                                isDark,
                              ),
                            ),
                            Expanded(
                              child: _categoryTab(
                                'Only in PPP',
                                _onlyInPPP.length,
                                1,
                                Colors.amber,
                                isDark,
                              ),
                            ),
                            Expanded(
                              child: _categoryTab(
                                'Synced',
                                _synced.length,
                                2,
                                Colors.green,
                                isDark,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Search Bar
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                          style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: 'Cari username atau profile...',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.clear,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor:
                                isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      // User List
                      Expanded(
                        child: _buildUserList(isDark),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _summaryCard(
      String label, int count, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _categoryTab(
      String label, int count, int index, Color color, bool isDark) {
    final isSelected = _selectedCategory == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = index;
          _searchQuery = '';
          _searchController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: color, width: 2) : null,
        ),
        child: Column(
          children: [
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? color
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(bool isDark) {
    final users = _getFilteredUsers();

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.check_circle_outline,
              size: 64,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ada hasil pencarian'
                  : _selectedCategory == 0
                      ? 'Semua user di database ada di PPP! ✓'
                      : _selectedCategory == 1
                          ? 'Semua user di PPP ada di database! ✓'
                          : 'Tidak ada user yang sinkron',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final username = _selectedCategory == 1
            ? user['name']?.toString() ?? '-'
            : user['username']?.toString() ?? '-';
        final profile = user['profile']?.toString() ?? '-';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: _selectedCategory == 0
                  ? Colors.red.withOpacity(0.2)
                  : _selectedCategory == 1
                      ? Colors.amber.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
              child: Icon(
                _selectedCategory == 0
                    ? Icons.warning
                    : _selectedCategory == 1
                        ? Icons.add_circle_outline
                        : Icons.check_circle,
                color: _selectedCategory == 0
                    ? Colors.red
                    : _selectedCategory == 1
                        ? Colors.amber
                        : Colors.green,
              ),
            ),
            title: Text(
              username,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              profile,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            trailing: _selectedCategory == 0
                ? IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteUserFromDatabase(user),
                    tooltip: 'Hapus dari Database',
                  )
                : null,
          ),
        );
      },
    );
  }
}
