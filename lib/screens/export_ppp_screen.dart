import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';

import '../widgets/custom_snackbar.dart';
import '../widgets/gradient_container.dart';
import '../main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../providers/router_session_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show Directory, File, Platform;
import '../data/user_db_helper.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../services/backup_service.dart';

class ExportPPPScreen extends StatefulWidget {
  const ExportPPPScreen({Key? key}) : super(key: key);

  @override
  State<ExportPPPScreen> createState() => _ExportPPPScreenState();
}

class _ExportPPPScreenState extends State<ExportPPPScreen> {
  bool _isLoading = false;
  String? _error;
  int _totalUsers = 0;
  int _successCount = 0;
  int _failedCount = 0;
  List<Map<String, dynamic>> _failedUsers = [];
  String _currentProcess = '';

  Future<bool> saveUserToServer(Map<String, dynamic> userData) async {
    final url = Uri.parse('${ApiService.baseUrl}/save_user.php');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(userData),
    );
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['success'] == true;
    } else {
      return false;
    }
  }

  Future<void> _exportUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'Menghubungkan ke Mikrotik...';
    });

    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);

      // Get all PPP secrets from Mikrotik
      setState(() {
        _currentProcess = 'Mengambil data dari Mikrotik...';
      });

      final secrets = await provider.service.getPPPSecret();
      setState(() => _totalUsers = secrets.length);

      // Process each user
      for (var secret in secrets) {
        try {
          setState(() {
            _currentProcess =
                'Mengekspor ${_successCount + _failedCount + 1} dari $_totalUsers user...';
          });

          final userData = {
            'username': secret['name'],
            'password': secret['password'],
            'profile': secret['profile'],
            'wa': '',
            'foto': '',
            'maps': '',
            'tanggal_dibuat': DateTime.now().toIso8601String(),
          };

          final success = await saveUserToServer(userData);

          if (success) {
            setState(() => _successCount++);
          } else {
            setState(() {
              _failedCount++;
              _failedUsers.add({
                'username': secret['name'],
                'error': 'Gagal menyimpan ke database',
              });
            });
          }
        } catch (e) {
          setState(() {
            _failedCount++;
            _failedUsers.add({
              'username': secret['name'],
              'error': e.toString(),
            });
          });
        }
      }

      if (!mounted) return;

      if (_failedCount == 0) {
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor berhasil',
          additionalInfo: 'Berhasil mengekspor $_totalUsers user ke database',
          isSuccess: true,
        );
        Navigator.of(context).pop(true); // Return success
      } else {
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor selesai dengan beberapa error',
          additionalInfo: '$_successCount berhasil, $_failedCount gagal',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal mengekspor data',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Fungsi baru: ekspor massal ke database via API
  Future<void> _exportUsersToApi() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'Menghubungkan ke Mikrotik...';
    });
    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);

      setState(() {
        _currentProcess = 'Mengambil data dari Mikrotik...';
      });

      final secrets = await provider.service.getPPPSecret();
      setState(() => _totalUsers = secrets.length);

      // Siapkan data untuk API
      final users = secrets
          .map((secret) => {
                'username': secret['name'],
                'password': secret['password'],
                'profile': secret['profile'],
              })
          .toList();

      setState(() {
        _currentProcess = 'Mengekspor $_totalUsers user ke database...';
      });

      final result =
          await ApiService.exportUsers(List<Map<String, dynamic>>.from(users));
      if (result['success'] == true) {
        setState(() {
          _successCount = result['success_count'] ?? 0;
          _failedCount = result['failed_count'] ?? 0;
          _failedUsers =
              List<Map<String, dynamic>>.from(result['failed_users'] ?? []);
        });
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor selesai',
          additionalInfo: 'Berhasil: $_successCount, Gagal: $_failedCount',
          isSuccess: _failedCount == 0,
        );
      } else {
        setState(() {
          _error = result['error'] ?? 'Gagal ekspor ke database';
        });
        CustomSnackbar.show(
          context: context,
          message: 'Ekspor gagal',
          additionalInfo: _error ?? '',
          isSuccess: false,
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      CustomSnackbar.show(
        context: context,
        message: 'Ekspor gagal',
        additionalInfo: _error ?? '',
        isSuccess: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Unified sync: ambil PPP dari Mikrotik, lalu upsert ke DB (insert/update), termasuk router_id
  Future<void> _unifiedSyncToDb() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'Menghubungkan ke Mikrotik...';
    });
    try {
      // Create automatic full SQL backup before sync
      final routerId =
          Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId != null && routerId.isNotEmpty) {
        setState(() {
          _currentProcess = 'Membuat backup otomatis...';
        });

        final backupResult =
            await BackupService().createFullSQLBackup(routerId);
        if (!backupResult['success']) {
          // Show warning but continue with sync
          if (mounted) {
            CustomSnackbar.show(
              context: context,
              message: 'Peringatan Backup',
              additionalInfo:
                  'Gagal membuat backup otomatis: ${backupResult['error']}',
              isSuccess: false,
            );
          }
        } else if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Backup Otomatis',
            additionalInfo:
                'Backup SQL lengkap berhasil dibuat sebelum sinkronisasi',
            isSuccess: true,
          );
        }
      }

      setState(() {
        _currentProcess = 'Mengambil data dari Mikrotik...';
      });

      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final secrets = await provider.service.getPPPSecret();
      _totalUsers = secrets.length;

      // Normalisasi data minimal untuk sinkron
      final normalized = secrets
          .map((s) => {
                'name': s['name']?.toString() ?? '',
                'password': s['password']?.toString() ?? '',
                'profile': s['profile']?.toString() ?? '',
              })
          .where((u) => (u['name'] as String).isNotEmpty)
          .toList();

      // Ambil routerId aktif
      // final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null || routerId.isEmpty) {
        throw Exception('Router belum login');
      }

      // Kirim per-batch agar aman
      const int batchSize = 50;
      int added = 0;
      int updated = 0;
      final int totalBatches = (normalized.length / batchSize).ceil();

      for (int i = 0; i < normalized.length; i += batchSize) {
        final int currentBatch = (i ~/ batchSize) + 1;
        final batch = normalized.sublist(
            i,
            i + batchSize > normalized.length
                ? normalized.length
                : i + batchSize);

        setState(() {
          _currentProcess =
              'Memproses batch $currentBatch dari $totalBatches...';
          _successCount =
              currentBatch; // Use successCount to show batch progress
          _totalUsers = totalBatches; // Use totalUsers to show total batches
        });

        try {
          // Debug batch info
          // ignore: avoid_print
          print(
              '[SYNC] Batch $currentBatch/$totalBatches size=${batch.length}');
          final res = await ApiService.syncPPPUsers(
            routerId: routerId,
            pppUsers: List<Map<String, dynamic>>.from(batch),
            // MATIKAN prune sepenuhnya untuk mencegah kehilangan data
            prune: false,
          );
          added += (res['added'] ?? 0) as int;
          updated += (res['updated'] ?? 0) as int;
        } catch (e) {
          // ignore: avoid_print
          print('[SYNC][ERROR] Batch $currentBatch failed: $e');
          rethrow;
        }
      }

      if (!mounted) return;
      _successCount = added + updated;
      _totalUsers = added + updated + _failedCount; // Reset to show user count

      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sinkronisasi Selesai'),
          content: Text('Sinkronisasi berhasil:\n'
              '• Ditambahkan: $added user\n'
              '• Diperbarui: $updated user\n\n'
              'Backup otomatis dijalankan setiap hari pukul 02:00.\n\n'
              'Format file backup: pppoe-full-backup-[router-id]-[tahun-bulan-tanggal-jam-menit-detik].sql'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _error = e.toString();

      // Show error dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sinkronisasi Gagal'),
          content: Text(e.toString()),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Sinkronisasi dengan prune (untuk pengguna ahli)
  /*
  Future<void> _unifiedSyncToDbWithPrune() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'sync';
    });
    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final secrets = await provider.service.getPPPSecret();
      _totalUsers = secrets.length;

      // Normalisasi data minimal untuk sinkron
      final normalized = secrets
          .map((s) => {
                'name': s['name']?.toString() ?? '',
                'password': s['password']?.toString() ?? '',
                'profile': s['profile']?.toString() ?? '',
              })
          .where((u) => (u['name'] as String).isNotEmpty)
          .toList();

      // Ambil routerId aktif
      final routerId = Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null || routerId.isEmpty) {
        throw Exception('Router belum login');
      }

      // Peringatan khusus untuk prune
      if (!mounted) return;
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('PERINGATAN: Sinkronisasi dengan Prune'),
          content: const Text(
            'PERINGATAN KEAMANAN:\n\n'
            'Fitur "prune" akan MENGHAPUS semua user di database yang TIDAK ADA di Mikrotik saat ini.\n\n'
            'Ini akan menghapus:\n'
            '- Data user yang tidak ada di Mikrotik\n'
            '- Data billing terkait user tersebut\n'
            '- Semua data tambahan (WA, Maps, Foto)\n\n'
            'GUNAKAN HANYA jika Anda yakin:\n'
            '1. Data di Mikrotik adalah data terbaru\n'
            '2. Anda memiliki backup database\n\n'
            'LANJUTKAN DENGAN HATI-HATI?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LANJUTKAN (BERBAHAYA)'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Konfirmasi kedua
      final finalConfirmation = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('KONFIRMASI TERAKHIR'),
          content: const Text(
            'INI ADALAH KONFIRMASI TERAKHIR.\n\n'
            'Anda akan kehilangan SEMUA data user yang tidak ada di Mikrotik saat ini, termasuk data billing dan data tambahan.\n\n'
            'Ketik "SAYA MENGERTI" untuk melanjutkan:'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('SAYA MENGERTI - HAPUS DATA'),
            ),
          ],
        ),
      );

      if (finalConfirmation != true) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Kirim per-batch agar aman
      const int batchSize = 50;
      int added = 0;
      int updated = 0;
      int pruned = 0;
      for (int i = 0; i < normalized.length; i += batchSize) {
        final batch = normalized.sublist(i, i + batchSize > normalized.length ? normalized.length : i + batchSize);
        try {
          // Debug batch info
          // ignore: avoid_print
          print('[SYNC] Batch ${(i ~/ batchSize) + 1}/${(normalized.length / batchSize).ceil()} size=${batch.length}');
          final res = await ApiService.syncPPPUsers(
            routerId: routerId,
            pppUsers: List<Map<String, dynamic>>.from(batch),
            // Hanya aktifkan prune di batch pertama
            prune: i == 0,
          );
          added += (res['added'] ?? 0) as int;
          updated += (res['updated'] ?? 0) as int;
          if (i == 0) {
            pruned = (res['pruned'] ?? 0) as int;
          }
        } catch (e) {
          // ignore: avoid_print
          print('[SYNC][ERROR] Batch ${(i ~/ batchSize) + 1} failed: $e');
          rethrow;
        }
      }

      if (!mounted) return;
      _successCount = added + updated;
      CustomSnackbar.show(
        context: context,
        message: 'Sinkronisasi selesai',
        additionalInfo: 'Ditambahkan: $added, Diperbarui: $updated, Dihapus: $pruned',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      _error = e.toString();
      CustomSnackbar.show(
        context: context,
        message: 'Sinkronisasi gagal',
        additionalInfo: _error ?? '',
        isSuccess: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Database Setting',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SizedBox.expand(
        child: GradientContainer(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info Card - Modern Design
                  Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E3A5F), const Color(0xFF2D2D2D)]
                            : [Colors.blue.shade50, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withOpacity(0.3)
                              : Colors.blue.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.blue.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  color: isDark
                                      ? Colors.blue[300]!
                                      : Colors.blue[700]!,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Informasi Sinkronisasi & Backup',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.blue.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sinkronisasi',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.blue[300]
                                        : Colors.blue[700],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Perbarui data user dari Mikrotik ke database',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _buildInfoItem(Icons.person_outline_rounded,
                                    'Username, Password, Profile', isDark),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Fitur Keamanan:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildFeatureItem(
                            Icons.shield_outlined,
                            'Backup otomatis sebelum sinkronisasi',
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          _buildFeatureItem(
                            Icons.save_outlined,
                            'Data tambahan dipertahankan',
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          _buildFeatureItem(
                            Icons.receipt_long_outlined,
                            'Data billing dipertahankan',
                            isDark,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Backup Otomatis:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildFeatureItem(
                            Icons.schedule_outlined,
                            'Harian: 02:00 | Format: pppoe-full-backup-[ID]-[tgl].sql',
                            isDark,
                          ),
                          const SizedBox(height: 6),
                          _buildFeatureItem(
                            Icons.folder_outlined,
                            'Disimpan di folder Download perangkat',
                            isDark,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Main Action Buttons - Modern Design
                  // Button 1: Sinkronkan Semua User
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.blue[700]!, Colors.blue[900]!]
                            : [Colors.blue[600]!, Colors.blue[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.sync_alt, size: 22),
                      label: const Text(
                        'Sinkronkan Semua User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _unifiedSyncToDb,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Button 2: Backup Database
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.green[700]!, Colors.green[900]!]
                            : [Colors.green[600]!, Colors.green[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cloud_download, size: 22),
                      label: const Text(
                        'Backup Database',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _backupDatabase,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Button 3: Import dari File
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.orange[700]!, Colors.orange[900]!]
                            : [Colors.orange[600]!, Colors.orange[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.file_upload, size: 22),
                      label: const Text(
                        'Import dari File',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _importFromFile,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Button 4: Cek Database Sync (NEW)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.deepPurple[600]!, Colors.deepPurple[800]!]
                            : [
                                Colors.deepPurple[500]!,
                                Colors.deepPurple[700]!
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.compare_arrows, size: 22),
                      label: const Text(
                        'Cek Database Sync',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/database-sync');
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Progress Card
                  if (_isLoading || _totalUsers > 0)
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timelapse,
                                  color: isDark
                                      ? Colors.blue[200]!
                                      : Colors.blue[800]!,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Progress',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_isLoading)
                              Column(
                                children: [
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _currentProcess == 'backup'
                                        ? 'Mohon tunggu, sedang membackup database...'
                                        : _currentProcess == 'import'
                                            ? 'Mohon tunggu, sedang mengimpor data...'
                                            : _currentProcess,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.blue[200]!
                                          : Colors.blue[800]!,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  if (_totalUsers > 0)
                                    Text(
                                      _currentProcess.contains('batch')
                                          ? _currentProcess
                                              .replaceAll('Memproses ', '')
                                              .replaceAll('Mengimport ', '')
                                          : 'Langkah $_successCount dari $_totalUsers',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.blue[300]!
                                            : Colors.blue[700]!,
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                ],
                              )
                            else ...[
                              Center(
                                child: Column(
                                  children: [
                                    _buildProgressItem(
                                      'Total User',
                                      _totalUsers.toString(),
                                      isDark
                                          ? Colors.blue[200]!
                                          : Colors.blue[800]!,
                                      isDark,
                                    ),
                                    _buildProgressItem(
                                      'Berhasil',
                                      _successCount.toString(),
                                      isDark
                                          ? Colors.green[300]!
                                          : Colors.green[700]!,
                                      isDark,
                                    ),
                                    _buildProgressItem(
                                      'Gagal',
                                      _failedCount.toString(),
                                      isDark
                                          ? Colors.red[300]!
                                          : Colors.red[700]!,
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Failed Users List
                  if (_failedUsers.isNotEmpty) ...[
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: isDark
                                      ? Colors.red[300]!
                                      : Colors.red[700]!,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Daftar User Gagal',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _failedUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _failedUsers[index];
                                  return ListTile(
                                    leading: Icon(
                                      Icons.error,
                                      color: isDark
                                          ? Colors.red[300]!
                                          : Colors.red[700]!,
                                    ),
                                    title: Text(
                                      user['username'],
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                    subtitle: Text(
                                      user['error'],
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.red[200]!
                                            : Colors.red[700]!,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Error message
                  if (_error != null)
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.red[900] : Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.red[700]! : Colors.red[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color:
                                  isDark ? Colors.red[200]! : Colors.red[700]!,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.red[100]
                                      : Colors.red[800],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.blue[300]! : Colors.blue[700]!,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.green.withOpacity(0.2)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: isDark ? Colors.green[300]! : Colors.green[700]!,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.grey[700],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressItem(
      String label, String value, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _importFromFile() async {
    try {
      // Show information dialog first
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Database'),
          content: const Text(
              'Pilih file SQL backup untuk diimport ke database.\n\n'
              'File harus dalam format SQL yang dihasilkan oleh fitur backup aplikasi.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Lanjutkan'),
            ),
          ],
        ),
      );

      setState(() {
        _isLoading = true;
        _error = null;
        _totalUsers = 0;
        _successCount = 0;
        _failedCount = 0;
        _failedUsers = [];
        _currentProcess = 'Memeriksa izin penyimpanan...';
      });

      // 1. Request storage permissions first
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Show settings dialog if permission is denied
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Izin Penyimpanan'),
              content: const Text(
                  'Untuk mengimport file backup, aplikasi memerlukan izin penyimpanan.\n\n'
                  'Silakan:\n'
                  '1. Buka Pengaturan\n'
                  '2. Pilih "Izinkan pengelolaan semua file"\n'
                  '3. Aktifkan untuk aplikasi PPPoE'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('TUTUP'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('BUKA PENGATURAN'),
                ),
              ],
            ),
          );

          if (openSettings == true) {
            await openAppSettings();
          }
          throw Exception('Izin penyimpanan diperlukan untuk import database');
        }
      }

      setState(() {
        _currentProcess = 'Mencari file backup...';
      });

      // 2. For now, we'll implement a simple import from a predefined path
      // In a real implementation, you would use a file picker here
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('Tidak dapat mengakses penyimpanan eksternal');
      }

      // Navigate up to get to the Download folder
      String downloadPath = externalDir.path;
      List<String> paths = downloadPath.split("/");
      int androidIndex = paths.indexOf("Android");
      if (androidIndex != -1) {
        paths = paths.sublist(0, androidIndex);
        downloadPath = paths.join("/") + "/Download";
      }

      // For now, we'll look for SQL files in the Download folder
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        throw Exception('Folder Download tidak ditemukan');
      }

      // List SQL files in Download folder
      final sqlFiles = downloadDir
          .listSync()
          .where((entity) => entity is File && entity.path.endsWith('.sql'))
          .toList();

      // Sort files by modification time (newest first)
      sqlFiles.sort((a, b) {
        final fileA = a as File;
        final fileB = b as File;
        return fileB.statSync().modified.compareTo(fileA.statSync().modified);
      });

      if (sqlFiles.isEmpty) {
        throw Exception('Tidak ditemukan file SQL backup di folder Download');
      }

      // Show file selection dialog
      if (!mounted) return;
      final selectedFile = await showDialog<File?>(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: const Text('Pilih File Backup'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sqlFiles.length,
                itemBuilder: (context, index) {
                  final file = sqlFiles[index] as File;
                  final fileName = path.basename(file.path);
                  // Extract just the date part from the filename if it follows the backup naming pattern
                  String displayFileName = fileName;
                  String fileDateTime = '';

                  try {
                    // Try to extract date/time from filename pattern: pppoe-full-backup-[router-id]-[tahun-bulan-tanggal-jam-menit-detik].sql
                    if (fileName.contains('pppoe-full-backup-')) {
                      final parts = fileName.split('-');
                      if (parts.length >= 8) {
                        // Get the date parts (tahun-bulan-tanggal)
                        final year = parts[parts.length - 4];
                        final month = parts[parts.length - 3];
                        final day = parts[parts.length - 2];
                        final timePart = parts[parts.length - 1]
                            .split('.')[0]; // Remove .sql extension

                        if (timePart.length >= 6) {
                          final hour = timePart.substring(0, 2);
                          final minute = timePart.substring(2, 4);
                          final second = timePart.substring(4, 6);
                          displayFileName =
                              'pppoe-full-backup-${parts[3]}-$year-$month-$day.sql';
                          fileDateTime =
                              '$day/$month/$year $hour:$minute:$second';
                        }
                      }
                    }
                  } catch (e) {
                    // If parsing fails, use the original filename
                  }

                  // Get file size
                  final fileSize = file.lengthSync();
                  final fileSizeKB = fileSize ~/ 1024;

                  // Get file modification time as fallback
                  final fileStat = file.statSync();
                  final modTime = fileStat.modified;
                  final formattedDateTime =
                      DateFormat('dd/MM/yyyy HH:mm:ss').format(modTime);

                  // Use parsed date/time if available, otherwise use file modification time
                  final displayInfo = fileDateTime.isNotEmpty
                      ? '$fileDateTime | $fileSizeKB KB'
                      : '$formattedDateTime | $fileSizeKB KB';

                  return ListTile(
                    title: Text(displayFileName),
                    subtitle: Text(displayInfo),
                    onTap: () => Navigator.pop(context, file),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
            ],
          );
        },
      );

      // If no file selected, cancel import
      if (selectedFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Show confirmation dialog
      if (!mounted) return;
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Konfirmasi Import'),
          content: Text(
              'Apakah Anda yakin ingin mengimport data dari file:\n\n${path.basename(selectedFile.path)}?\n\n'
              'Data yang ada saat ini akan dihapus dan diganti dengan data dari file backup.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        setState(() => _isLoading = false);
        return;
      }

      setState(() {
        _currentProcess = 'Membaca file backup...';
      });

      // Read the SQL file content
      final sqlContent = await selectedFile.readAsString();

      // Parse the SQL content and extract user data
      final users = _parseSqlContent(sqlContent);

      setState(() {
        _totalUsers = users.length;
        _currentProcess = 'Menghapus data lama...';
      });

      // 3. Clear existing data in SQLite
      await UserDbHelper().clearAll();

      setState(() {
        _currentProcess = 'Mengimport data...';
        _successCount = 0;
      });

      // 4. Insert each user to SQLite in batches
      const int batchSize = 50;
      final int totalBatches = (users.length / batchSize).ceil();

      for (int i = 0; i < users.length; i += batchSize) {
        final int currentBatch = (i ~/ batchSize) + 1;
        final batch = users.sublist(
            i, i + batchSize > users.length ? users.length : i + batchSize);

        setState(() {
          _currentProcess =
              'Mengimport batch $currentBatch dari $totalBatches...';
          _successCount =
              currentBatch; // Use successCount to show batch progress
          _totalUsers = totalBatches; // Use totalUsers to show total batches
        });

        // Insert each user in the batch
        for (var userData in batch) {
          try {
            await UserDbHelper().insertUser(userData);
          } catch (e) {
            setState(() {
              _failedCount++;
              _failedUsers.add({
                'username': userData['username'],
                'error': e.toString(),
              });
            });
          }
        }
      }

      if (!mounted) return;

      // Reset counts for final display
      setState(() {
        _totalUsers = users.length;
        _successCount = users.length - _failedCount;
      });

      if (_failedCount == 0) {
        CustomSnackbar.show(
          context: context,
          message: 'Import berhasil',
          additionalInfo:
              'Berhasil mengimport $_totalUsers user ke database lokal',
          isSuccess: true,
        );
      } else {
        CustomSnackbar.show(
          context: context,
          message: 'Import selesai dengan beberapa error',
          additionalInfo: '$_successCount berhasil, $_failedCount gagal',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal mengimport data',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Parse SQL content and extract user data
  /// This is a simplified parser for demonstration purposes
  List<Map<String, dynamic>> _parseSqlContent(String sqlContent) {
    final users = <Map<String, dynamic>>[];

    // Simple regex to find INSERT statements for users table
    final insertRegex = RegExp(
      r"INSERT INTO `users`.*?VALUES\s*(.*?);",
      dotAll: true,
      multiLine: true,
    );

    final matches = insertRegex.allMatches(sqlContent);

    for (var match in matches) {
      final valuesSection = match.group(1);
      if (valuesSection != null) {
        // Parse each row of values
        final rowRegex = RegExp(r"\((.*?)\)", multiLine: true);
        final rowMatches = rowRegex.allMatches(valuesSection);

        for (var rowMatch in rowMatches) {
          final rowData = rowMatch.group(1);
          if (rowData != null) {
            // Split by comma but be careful with quoted strings
            final values = _splitSqlValues(rowData);
            if (values.length >= 8) {
              // Map to our local database format
              users.add({
                'username': _cleanSqlValue(values[2]), // username
                'password': _cleanSqlValue(values[3]), // password
                'profile': _cleanSqlValue(values[4]), // profile
                'wa': _cleanSqlValue(values[5]), // wa
                'maps': _cleanSqlValue(values[6]), // maps
                'foto': _cleanSqlValue(values[7]), // foto
                'tanggal_dibuat': _cleanSqlValue(values[8]), // tanggal_dibuat
              });
            }
          }
        }
      }
    }

    return users;
  }

  /// Split SQL values by comma, but respect quoted strings
  List<String> _splitSqlValues(String values) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool escapeNext = false;

    for (int i = 0; i < values.length; i++) {
      final char = values[i];

      if (escapeNext) {
        buffer.write(char);
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        buffer.write(char);
        continue;
      }

      if (char == "'") {
        inQuotes = !inQuotes;
        buffer.write(char);
        continue;
      }

      if (char == ',' && !inQuotes) {
        result.add(buffer.toString().trim());
        buffer.clear();
        continue;
      }

      buffer.write(char);
    }

    // Add the last value
    if (buffer.isNotEmpty) {
      result.add(buffer.toString().trim());
    }

    return result;
  }

  /// Clean SQL value (remove quotes, handle NULL)
  String _cleanSqlValue(String value) {
    if (value.toUpperCase() == 'NULL') {
      return '';
    }

    // Remove surrounding quotes if present
    if (value.startsWith("'") && value.endsWith("'") && value.length >= 2) {
      return value.substring(1, value.length - 1);
    }

    return value;
  }

  void _importFromServer() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'import';
    });

    try {
      // 1. Fetch data from server
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/get_all_users.php'),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Gagal mengambil data dari server: ${response.statusCode}');
      }

      final Map<String, dynamic> result = jsonDecode(response.body);

      if (result['success'] != true) {
        throw Exception('Gagal mengambil data: ${result['error']}');
      }

      final List<dynamic> serverUsers = result['users'];
      setState(() => _totalUsers = serverUsers.length);

      // 2. Clear existing data in SQLite
      await UserDbHelper().clearAll();

      // 3. Insert each user to SQLite
      for (var userData in serverUsers) {
        try {
          // Convert server data format to local database format
          final user = {
            'username': userData['username'],
            'password': userData['password'],
            'profile': userData['profile'],
            'wa': userData['wa'],
            'foto': userData['foto'],
            'maps': userData['maps'],
            'tanggal_dibuat': userData['tanggal_dibuat'],
          };

          await UserDbHelper().insertUser(user);
          setState(() => _successCount++);
        } catch (e) {
          setState(() {
            _failedCount++;
            _failedUsers.add({
              'username': userData['username'],
              'error': e.toString(),
            });
          });
        }
      }

      if (!mounted) return;

      if (_failedCount == 0) {
        CustomSnackbar.show(
          context: context,
          message: 'Import berhasil',
          additionalInfo:
              'Berhasil mengimport $_totalUsers user ke database lokal',
          isSuccess: true,
        );
      } else {
        CustomSnackbar.show(
          context: context,
          message: 'Import selesai dengan beberapa error',
          additionalInfo: '$_successCount berhasil, $_failedCount gagal',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal mengimport data',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _exportToSql() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Show confirmation dialog first
      if (!mounted) return;
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Izin Penyimpanan'),
          content: const Text(
              'Aplikasi memerlukan izin untuk menyimpan file backup di penyimpanan.\n\n'
              'File akan disimpan di folder Download dengan format:\n'
              'backup-userspppoe-[tanggal]-[waktu].sql'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LANJUTKAN'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Request storage permissions
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Show settings dialog if permission is denied
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Izin Ditolak'),
              content: const Text(
                  'Untuk menyimpan file, aplikasi memerlukan izin penyimpanan.\n\n'
                  'Silakan:\n'
                  '1. Buka Pengaturan\n'
                  '2. Pilih "Izinkan pengelolaan semua file"\n'
                  '3. Aktifkan untuk aplikasi PPPoE'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('TUTUP'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('BUKA PENGATURAN'),
                ),
              ],
            ),
          );

          if (openSettings == true) {
            await openAppSettings();
          }
          throw Exception(
              'Izin penyimpanan diperlukan untuk mengekspor database');
        }
      }

      // 3. Get external storage directory
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('Tidak dapat mengakses penyimpanan eksternal');
      }

      // Navigate up to get to the Download folder
      String downloadPath = externalDir.path;
      List<String> paths = downloadPath.split("/");
      int androidIndex = paths.indexOf("Android");
      if (androidIndex != -1) {
        paths = paths.sublist(0, androidIndex);
        downloadPath = paths.join("/") + "/Download";
      }

      // 4. Create filename with current date
      final now = DateTime.now();
      final dateStr = DateFormat('dd-MM-yyyy').format(now);
      final timeStr = DateFormat('HHmm').format(now);
      final fileName = 'backup-userspppoe-$dateStr-$timeStr.sql';
      final targetPath = path.join(downloadPath, fileName);

      // 5. Ensure download directory exists
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // 6. Get all users from local database (SQLite)
      final users = await UserDbHelper().getAllUsers();

      // 7. Generate SQL dump content
      final StringBuffer sqlContent = StringBuffer();

      // Write SQL header
      sqlContent.writeln('-- MySQL dump for PPPoE Users');
      sqlContent.writeln('-- Generated on ${DateTime.now().toIso8601String()}');
      sqlContent.writeln('');
      sqlContent.writeln('SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";');
      sqlContent.writeln('START TRANSACTION;');
      sqlContent.writeln('SET time_zone = "+00:00";');
      sqlContent.writeln('');
      sqlContent.writeln(
          '/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;');
      sqlContent.writeln(
          '/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;');
      sqlContent.writeln(
          '/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;');
      sqlContent.writeln('/*!40101 SET NAMES utf8mb4 */;');
      sqlContent.writeln('');

      // Create table structure
      sqlContent.writeln('--');
      sqlContent.writeln('-- Database: `pppoe_monitor`');
      sqlContent.writeln('--');
      sqlContent.writeln('');
      sqlContent.writeln(
          '-- --------------------------------------------------------');
      sqlContent.writeln('');
      sqlContent.writeln('--');
      sqlContent.writeln('-- Table structure for table `users`');
      sqlContent.writeln('--');
      sqlContent.writeln('');
      sqlContent.writeln('CREATE TABLE IF NOT EXISTS `users` (');
      sqlContent.writeln('  `id` int NOT NULL AUTO_INCREMENT,');
      sqlContent.writeln('  `username` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `password` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `profile` varchar(100) DEFAULT NULL,');
      sqlContent.writeln('  `wa` varchar(20) DEFAULT NULL,');
      sqlContent.writeln('  `foto` varchar(255) DEFAULT NULL,');
      sqlContent.writeln('  `maps` varchar(255) DEFAULT NULL,');
      sqlContent.writeln('  `tanggal_dibuat` datetime DEFAULT NULL,');
      sqlContent.writeln('  PRIMARY KEY (`id`)');
      sqlContent.writeln(
          ') ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;');
      sqlContent.writeln('');

      // Insert data
      if (users.isNotEmpty) {
        sqlContent.writeln('--');
        sqlContent.writeln('-- Dumping data for table `users`');
        sqlContent.writeln('--');
        sqlContent.writeln('');
        sqlContent.writeln(
            'INSERT INTO `users` (`username`, `password`, `profile`, `wa`, `foto`, `maps`, `tanggal_dibuat`) VALUES');

        for (var i = 0; i < users.length; i++) {
          final user = users[i];
          final username = _escapeSqlString(user['username']);
          final password = _escapeSqlString(user['password']);
          final profile = _escapeSqlString(user['profile']);
          final wa =
              user['wa'] != null ? "'${_escapeSqlString(user['wa'])}'" : 'NULL';
          final foto = user['foto'] != null
              ? "'${_escapeSqlString(user['foto'])}'"
              : 'NULL';
          final maps = user['maps'] != null
              ? "'${_escapeSqlString(user['maps'])}'"
              : 'NULL';
          final tanggalDibuat = user['tanggal_dibuat'] != null
              ? "'${user['tanggal_dibuat']}'"
              : 'NULL';

          sqlContent.write(
              "('$username', '$password', '$profile', $wa, $foto, $maps, $tanggalDibuat)");
          if (i < users.length - 1) {
            sqlContent.writeln(',');
          } else {
            sqlContent.writeln(';');
          }
        }
      }

      // Write SQL footer
      sqlContent.writeln('');
      sqlContent.writeln('COMMIT;');
      sqlContent.writeln('');
      sqlContent.writeln(
          '/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;');
      sqlContent.writeln(
          '/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;');
      sqlContent.writeln(
          '/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;');

      // 8. Write SQL content to file
      final file = File(targetPath);
      await file.writeAsString(sqlContent.toString());

      if (!mounted) return;

      CustomSnackbar.show(
        context: context,
        message: 'Ekspor berhasil',
        additionalInfo: 'File tersimpan di folder Download:\n$fileName',
        isSuccess: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal mengekspor data',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _escapeSqlString(String str) {
    if (str == null) return 'NULL';
    return str
        .replaceAll("'", "''")
        .replaceAll("\\", "\\\\")
        .replaceAll("\r", "\\r")
        .replaceAll("\n", "\\n")
        .replaceAll("\t", "\\t");
  }

  Future<void> _backupDatabase() async {
    // Show information dialog first
    if (!mounted) return;
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Database'),
        content: const Text(
            'Backup otomatis sudah berjalan setiap hari pukul 02:00.\n\n'
            'Anda juga dapat membuat backup manual dengan mengklik tombol "Lanjutkan".\n\n'
            'File backup akan disimpan di folder Download perangkat dalam format SQL lengkap.\n\n'
            'Format nama file: pppoe-full-backup-[router-id]-[tahun-bulan-tanggal-jam-menit-detik].sql'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    // If user cancels, return early
    if (shouldProceed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _totalUsers = 0;
      _successCount = 0;
      _failedCount = 0;
      _failedUsers = [];
      _currentProcess = 'Membuat backup database...';
    });

    try {
      // 1. Request storage permissions first
      if (Platform.isAndroid) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // Show settings dialog if permission is denied
          if (!mounted) return;
          final openSettings = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Izin Penyimpanan'),
              content: const Text(
                  'Untuk menyimpan file backup, aplikasi memerlukan izin penyimpanan.\n\n'
                  'Silakan:\n'
                  '1. Buka Pengaturan\n'
                  '2. Pilih "Izinkan pengelolaan semua file"\n'
                  '3. Aktifkan untuk aplikasi PPPoE'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('TUTUP'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('BUKA PENGATURAN'),
                ),
              ],
            ),
          );

          if (openSettings == true) {
            await openAppSettings();
          }
          throw Exception('Izin penyimpanan diperlukan untuk backup database');
        }
      }

      // Update progress: Starting backup process
      setState(() {
        _totalUsers = 3; // Representing 3 steps for the backup process
        _successCount = 0;
      });

      // 2. Create full SQL backup
      final routerId =
          Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null || routerId.isEmpty) {
        throw Exception('Router belum login');
      }

      // Update progress: Creating backup
      if (mounted) {
        setState(() {
          _currentProcess = 'Membuat backup database...';
          _successCount = 1;
        });
      }

      final backupResult = await BackupService().createFullSQLBackup(routerId);
      if (backupResult['success'] != true) {
        throw Exception(backupResult['error']);
      }

      // Update progress: Backup created successfully
      if (mounted) {
        setState(() {
          _currentProcess = 'Menyalin file backup...';
          _successCount = 2;
        });
      }

      // 3. Copy backup file to Download folder
      final sourceFile = File(backupResult['file_path']);
      final fileName = backupResult['file_name'];

      // Get external storage directory for SQL backup
      final externalDir = await getExternalStorageDirectory();
      if (externalDir == null) {
        throw Exception('Tidak dapat mengakses penyimpanan eksternal');
      }

      // Navigate up to get to the Download folder
      String downloadPath = externalDir.path;
      List<String> paths = downloadPath.split("/");
      int androidIndex = paths.indexOf("Android");
      if (androidIndex != -1) {
        paths = paths.sublist(0, androidIndex);
        downloadPath = paths.join("/") + "/Download";
      }

      // Ensure download directory exists
      final downloadDir = Directory(downloadPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Copy file to Download folder
      final targetPath = path.join(downloadPath, fileName);
      await sourceFile.copy(targetPath);

      // Delete temporary file
      await sourceFile.delete();

      // Update progress: Process completed
      if (mounted) {
        setState(() {
          _currentProcess = 'Backup selesai!';
          _successCount = 3;
        });
      }

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup Berhasil'),
          content: Text(
              'File backup telah tersimpan di folder Download:\n\n$fileName\n\n'
              'Backup otomatis dijalankan setiap hari pukul 02:00.\n\n'
              'Format nama file otomatis: pppoe-full-backup-[router-id]-[tahun-bulan-tanggal-jam-menit-detik].sql'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());

      // Show error dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup Gagal'),
          content: Text(e.toString()),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _syncPPPtoDB() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final pppUsers = await provider.service.getPPPSecret();
      // Kirim ke API sync_ppp_to_db.php
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/sync_ppp_to_db.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'ppp_users': pppUsers}),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        CustomSnackbar.show(
          context: context,
          message: 'Sinkronisasi selesai',
          additionalInfo: '${data['added']} user baru ditambahkan ke database',
          isSuccess: true,
        );
      } else {
        CustomSnackbar.show(
          context: context,
          message: 'Sinkronisasi gagal',
          additionalInfo: data['error'] ?? '',
          isSuccess: false,
        );
      }
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Sinkronisasi gagal',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
