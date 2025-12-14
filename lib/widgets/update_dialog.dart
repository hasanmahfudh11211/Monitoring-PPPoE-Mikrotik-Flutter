import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/update_service.dart';
import 'update_download_dialog.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final bool isRequired;
  final VoidCallback? onUpdate;

  const UpdateDialog({
    Key? key,
    required this.updateInfo,
    this.isRequired = false,
    this.onUpdate,
  }) : super(key: key);

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  bool _isInstalling = false;
  int _downloadedBytes = 0;
  int _totalBytes = 0;

  Future<void> _handleDownload() async {
    try {
      setState(() => _isDownloading = true);

      final filePath = await UpdateService.downloadApk(
        widget.updateInfo.apkUrl,
        (downloaded, total) {
          if (mounted) {
            setState(() {
              _downloadedBytes = downloaded;
              _totalBytes = total;
            });
          }
        },
      );

      // Download complete, try to install
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = true;
        });

        // Log path for debugging
        print('[UPDATE] Downloaded to: $filePath');

        final installed = await UpdateService.installApk(filePath);

        if (mounted) {
          setState(() => _isInstalling = false);

          if (widget.isRequired || installed) {
            Navigator.of(context).pop();
          }

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(installed
                    ? 'APK berhasil diunduh. Membuka installer...'
                    : 'APK disimpan di: $filePath'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isInstalling = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return PopScope(
      canPop: !_isDownloading, // Prevent dismissing if downloading
      child: _isDownloading
          ? UpdateDownloadDialog(
              downloadedBytes: _downloadedBytes, totalBytes: _totalBytes)
          : _isInstalling
              ? _buildInstallingDialog(context, isDark)
              : _buildUpdateInfoDialog(context, isDark),
    );
  }

  Widget _buildInstallingDialog(BuildContext context, bool isDark) {
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.green.shade900,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.install_mobile_rounded,
                color: Colors.green, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Installing Update',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87)),
          ),
        ],
      ),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text('Opening installer...',
            style: TextStyle(
                fontSize: 14, color: isDark ? Colors.white70 : Colors.black54)),
      ]),
    );
  }

  Widget _buildUpdateInfoDialog(BuildContext context, bool isDark) {
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: widget.isRequired
                  ? (isDark ? Colors.orange.shade900 : Colors.orange.shade50)
                  : (isDark ? Colors.blue.shade900 : Colors.blue.shade50),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.isRequired
                  ? Icons.warning_rounded
                  : Icons.system_update_rounded,
              color: widget.isRequired ? Colors.orange : Colors.blue,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isRequired ? 'Update Diperlukan' : 'Update Tersedia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.shade900 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.blue.shade700 : Colors.blue.shade200,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Versi Terbaru:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                    ),
                  ),
                  Text(
                    'v${widget.updateInfo.latestVersion} (Build ${widget.updateInfo.latestBuild})',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color:
                          isDark ? Colors.blue.shade100 : Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // File size
            Row(
              children: [
                Icon(
                  Icons.file_download,
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ukuran: ${widget.updateInfo.formattedSize}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Release notes
            if (widget.updateInfo.releaseNotes.isNotEmpty) ...[
              Text(
                'Perubahan:',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isDark ? const Color(0xFF2D2D2D) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.updateInfo.releaseNotes.map((note) {
                    final version = note['version'] ?? '';
                    final date = note['date'] ?? '';
                    final notes = List<String>.from(note['notes'] ?? []);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'v$version - $date',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          ...notes.map((item) => Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, top: 2),
                                child: Text(
                                  '• $item',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              )),
                        ],
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Warning if required
            if (widget.isRequired)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update ini wajib untuk melanjutkan penggunaan aplikasi.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'NANTI',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontWeight:
                  widget.isRequired ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: widget.onUpdate ?? () => _handleDownload(),
          icon: const Icon(Icons.download_rounded, size: 18),
          label: const Text(
            'DOWNLOAD',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.isRequired ? Colors.blue : Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}
