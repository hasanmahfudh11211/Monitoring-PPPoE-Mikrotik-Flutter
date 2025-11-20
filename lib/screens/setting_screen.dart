import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/gradient_container.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../main.dart';

import '../widgets/update_dialog.dart';
import '../services/update_service.dart';
import '../services/mikrotik_service.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({Key? key}) : super(key: key);

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  String _currentIp = '';
  String _currentPort = '';
  String _currentUsername = '';
  String _currentUserGroup = '';
  String _appVersion = '';
  bool _showNotifications = true;
  bool _loadingGroup = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
    });
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentIp = prefs.getString('ip') ?? '';
      _currentPort = prefs.getString('port') ?? '';
      _currentUsername = prefs.getString('username') ?? '';
      _showNotifications = prefs.getBool('showNotifications') ?? true;
    });

    // Load group info after settings are loaded
    if (_currentIp.isNotEmpty &&
        _currentPort.isNotEmpty &&
        _currentUsername.isNotEmpty) {
      _loadUserGroupInfo();
    }
  }

  Future<void> _loadUserGroupInfo() async {
    // Only try to load group info if we have connection details
    if (_currentIp.isEmpty ||
        _currentPort.isEmpty ||
        _currentUsername.isEmpty) {
      return;
    }

    setState(() {
      _loadingGroup = true;
      _currentUserGroup = ''; // Reset group info while loading
    });

    try {
      // Create a temporary Mikrotik service to fetch user info
      final prefs = await SharedPreferences.getInstance();
      final password = prefs.getString('password') ?? '';

      if (password.isEmpty) {
        setState(() {
          _loadingGroup = false;
          _currentUserGroup = 'Password not available';
        });
        return;
      }

      final service = MikrotikService(
        ip: _currentIp,
        port: _currentPort,
        username: _currentUsername,
        password: password,
      );

      try {
        // Try to get system users first (primary method)
        final users = await service.getSystemUsers();

        // Find the user that matches the current username
        final currentUser = users.firstWhere(
          (user) =>
              user['name'] != null &&
              user['name'].toString() == _currentUsername,
          orElse: () => {},
        );

        if (currentUser.isNotEmpty) {
          final group = currentUser['group']?.toString();
          if (group != null && group.isNotEmpty) {
            try {
              // Get group details for better information
              final groups = await service.getSystemUserGroups();
              final groupInfo = groups.firstWhere(
                (g) => g['name'] != null && g['name'].toString() == group,
                orElse: () => {'name': group},
              );

              final groupName = groupInfo['name']?.toString() ?? group;
              final groupDescription =
                  groupInfo['description']?.toString() ?? '';

              setState(() {
                _currentUserGroup = groupDescription.isNotEmpty
                    ? '$groupName ($groupDescription)'
                    : groupName;
              });
            } catch (groupError) {
              // If we can't get group details, just show the group name
              setState(() {
                _currentUserGroup = group;
              });
            }
          } else {
            setState(() {
              _currentUserGroup = 'No group assigned';
            });
          }
        } else {
          // If user not found in system users, try fallback method
          throw Exception('User not found in system users');
        }
      } catch (e) {
        // If system/user endpoint is not available, fallback to PPP secret method
        if (e.toString().contains('Endpoint not available') ||
            e.toString().contains('400') ||
            e.toString().contains('User not found')) {
          try {
            final group =
                await service.getUserGroupFromPPPSecret(_currentUsername);
            setState(() {
              _currentUserGroup = group;
            });
          } catch (pppError) {
            setState(() {
              _currentUserGroup =
                  'Error: ${pppError.toString().split(': ').last}';
            });
          }
        } else {
          setState(() {
            _currentUserGroup = 'Error: ${e.toString().split(': ').last}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _currentUserGroup = 'Error: ${e.toString().split(': ').last}';
      });
    } finally {
      setState(() {
        _loadingGroup = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showNotifications', _showNotifications);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan berhasil disimpan'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Setting',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadUserGroupInfo,
              tooltip: 'Refresh Group Info',
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Info Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection Info',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Informasi koneksi saat ini ke perangkat Mikrotik',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Left-right layout for connection info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column: IP and Port
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                    Icons.router,
                                    'IP Address',
                                    _currentIp.isEmpty
                                        ? 'Not configured'
                                        : _currentIp,
                                    isDark),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    Icons.person,
                                    'Username',
                                    _currentUsername.isEmpty
                                        ? 'Not configured'
                                        : _currentUsername,
                                    isDark),
                              ],
                            ),
                          ),
                          const SizedBox(
                              width: 16), // Add some space between columns
                          // Right column: Username and Group
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInfoRow(
                                    Icons.settings_ethernet,
                                    'Port',
                                    _currentPort.isEmpty
                                        ? 'Not configured'
                                        : _currentPort,
                                    isDark),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    Icons.group,
                                    'Group',
                                    _loadingGroup
                                        ? 'Loading...'
                                        : (_currentUserGroup.isEmpty
                                            ? 'Not loaded'
                                            : _currentUserGroup),
                                    isDark),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loadUserGroupInfo,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh Group Info'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // API Configuration Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'API Configuration',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Kelola konfigurasi Base URL API untuk koneksi ke server',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/api-config');
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text('Buka Konfigurasi API'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.blue[700] : Colors.blue[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // App Settings Section
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Text(
                          'Dark Mode',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Mengaktifkan tema gelap',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        value: isDark,
                        onChanged: (bool value) {
                          themeProvider.toggleTheme();
                        },
                      ),
                      SwitchListTile(
                        title: Text(
                          'Notifikasi',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Tampilkan notifikasi perubahan status',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        value: _showNotifications,
                        onChanged: (bool value) {
                          setState(() {
                            _showNotifications = value;
                          });
                          _saveSettings();
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildUpdateCheckButton(isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Logout Button
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildActionButton(
                        icon: Icons.cloud_upload,
                        label: 'Restore/Backup Database',
                        onPressed: () {
                          Navigator.pushNamed(context, '/export-ppp');
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildActionButton(
                        icon: Icons.logout,
                        label: 'Logout',
                        onPressed: () => _showLogoutConfirmation(context),
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.blue[200] : Colors.blue[800],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              color ?? (isDark ? Colors.blue[700] : Colors.blue[800]),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildUpdateCheckButton(bool isDark) {
    return InkWell(
      onTap: _checkForUpdates,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.system_update,
              size: 20,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            const SizedBox(width: 12),
            Text(
              'Check for Updates',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Check for updates
      final updateInfo = await UpdateService.checkForUpdate();

      // Close loading dialog
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show update dialog if available
      if (updateInfo.updateAvailable && mounted) {
        await showDialog(
          context: context,
          builder: (context) => UpdateDialog(
            updateInfo: updateInfo,
            isRequired: updateInfo.updateRequired,
          ),
        );
      } else if (mounted) {
        // Already up to date
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Aplikasi sudah menggunakan versi terbaru!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memeriksa update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Konfirmasi Logout',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar?',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Batal',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }
}
