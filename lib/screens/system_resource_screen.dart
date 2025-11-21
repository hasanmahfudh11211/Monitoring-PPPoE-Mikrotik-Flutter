import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';

import '../services/router_image_service.dart';
import '../services/router_image_service_simple.dart';
import '../main.dart';
import 'dart:async';
import 'dart:convert';
import '../widgets/gradient_container.dart';

class SystemResourceScreen extends StatefulWidget {
  const SystemResourceScreen({Key? key}) : super(key: key);

  @override
  State<SystemResourceScreen> createState() => _SystemResourceScreenState();
}

class _SystemResourceScreenState extends State<SystemResourceScreen> {
  Timer? _timer;
  String? _lastBoardName;
  late Future<String> _imageFuture;

  @override
  void initState() {
    super.initState();
    // Force refresh data immediately on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MikrotikProvider>();
      provider.refreshData(forceRefresh: true);
    });

    // Initialize the image future with a default value
    _imageFuture = Future.value('assets/mikrotik_product_images/default.png');

    // Auto-refresh every 1 second for realtime data
    // Using fetchResourceOnly() to reduce API calls (only identity + resource)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final provider = context.read<MikrotikProvider>();
      if (!provider.isLoading) {
        // Only fetch resource data, not all data (reduces API calls)
        provider.fetchResourceOnly();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Method to update the image future only when board name changes
  Future<String> _getImageFuture(String? boardName) {
    if (_lastBoardName != boardName) {
      _lastBoardName = boardName;
      _imageFuture = RouterImageServiceSimple.getRouterImageUrl(boardName);
      print(
          'SystemResourceScreen: Board name changed from $_lastBoardName to $boardName, updating image');
    } else {
      print(
          'SystemResourceScreen: Board name unchanged ($_lastBoardName), using cached image');
    }
    return _imageFuture;
  }

  Widget _buildResourceCard(
      String title, String value, IconData icon, bool isDark) {
    return Card(
      elevation: isDark ? 2 : 1,
      color: isDark
          ? const Color(0xFF1E1E1E)
          : Colors.white, // Changed to pure white
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.white, // Changed to pure white
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isDark ? Colors.blue[200] : Colors.blue[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLicenseFeaturesCard(dynamic features, bool isDark) {
    String featuresText = '-';

    if (features != null) {
      if (features is List) {
        // Handle list of features
        featuresText = features.join(', ');
      } else if (features is String) {
        // Handle string (might be comma-separated or space-separated)
        featuresText = features;
      } else {
        featuresText = features.toString();
      }
    }

    return Card(
      elevation: isDark ? 2 : 1,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.white, // Changed to pure white
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.extension,
                color: isDark ? Colors.blue[200] : Colors.blue[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Features',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    featuresText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    softWrap: true,
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouterImage(String? boardName, bool isDark) {
    final displayName = RouterImageService.getRouterDisplayName(boardName);

    // Create a GlobalKey to access the FutureBuilder state
    final imageKey = GlobalKey();

    return Container(
      width: double.infinity,
      height: 120,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GestureDetector(
          onTap: () {
            // Show zoomed image dialog
            _showZoomedImageDialog(context, imageKey, boardName, isDark);
          },
          child: Stack(
            children: [
              // Router Image with Future Builder
              Container(
                key: imageKey,
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent, // Make background transparent
                child: FutureBuilder<String>(
                  future: _getImageFuture(
                      boardName), // This will now properly cache the image
                  builder: (context, snapshot) {
                    print(
                        'SystemResourceScreen: FutureBuilder snapshot state: ${snapshot.connectionState}');
                    print(
                        'SystemResourceScreen: FutureBuilder hasData: ${snapshot.hasData}');
                    print(
                        'SystemResourceScreen: FutureBuilder data: ${snapshot.data}');
                    print(
                        'SystemResourceScreen: FutureBuilder error: ${snapshot.error}');

                    if (snapshot.hasError) {
                      print(
                          'SystemResourceScreen: Error loading router image: ${snapshot.error}');
                      // Show default.png when there's an error
                      return _buildCachedImage(
                          'assets/mikrotik_product_images/default.png', isDark,
                          isAsset: true);
                    }

                    // If we already have data, show it immediately without going through loading state
                    if (snapshot.hasData) {
                      print(
                          'SystemResourceScreen: Loading cached image with URL: ${snapshot.data}');
                      return _buildCachedImage(snapshot.data!, isDark);
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      print('SystemResourceScreen: Loading router image...');
                      return Container(
                        color:
                            Colors.transparent, // Make background transparent
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color:
                                  isDark ? Colors.blue[200] : Colors.blue[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading image...',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    print(
                        'SystemResourceScreen: No data or empty data, showing default image');
                    // Show default.png when no data is available
                    return _buildCachedImage(
                        'assets/mikrotik_product_images/default.png', isDark,
                        isAsset: true);
                  },
                ),
              ),
              // Router Name Overlay with white background and shadow
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white, // White background
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: Colors
                          .black, // Black text for better contrast on white background
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCachedImage(String imageUrl, bool isDark,
      {bool isAsset = false}) {
    if (isAsset) {
      // Handle asset images
      return Image.asset(
        imageUrl,
        fit: BoxFit
            .contain, // Changed to BoxFit.contain for better zoom experience
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('SystemResourceScreen: Error loading asset image: $error');
          // Fallback to icon if asset also fails
          return Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.router,
                  size: 60,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Handle network images
    return Image.network(
      imageUrl,
      fit: BoxFit
          .contain, // Changed to BoxFit.contain for better zoom experience
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isDark ? Colors.blue[200] : Colors.blue[600],
              ),
              const SizedBox(height: 8),
              Text(
                'Loading image...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('SystemResourceScreen: Error loading cached image: $error');
        // Show default.png when network image fails
        return _buildCachedImage(
            'assets/mikrotik_product_images/default.png', isDark,
            isAsset: true);
      },
    );
  }

  Widget _buildCachedImageForZoom(String imageUrl, bool isDark,
      {bool isAsset = false}) {
    if (isAsset) {
      // Handle asset images with zoom capability
      return Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print(
              'SystemResourceScreen (Zoom): Error loading asset image: $error');
          // Fallback to icon if asset also fails
          return Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.router,
                  size: 60,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Handle network images with zoom capability
    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isDark ? Colors.blue[200] : Colors.blue[600],
              ),
              const SizedBox(height: 8),
              Text(
                'Loading image...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print(
            'SystemResourceScreen (Zoom): Error loading cached image: $error');
        // Show default.png when network image fails
        return _buildCachedImageForZoom(
            'assets/mikrotik_product_images/default.png', isDark,
            isAsset: true);
      },
    );
  }

  Widget _buildInteractiveImage(String imageUrl, bool isDark,
      {bool isAsset = false}) {
    Widget imageWidget;

    if (isAsset) {
      // Handle asset images with interactive zoom
      imageWidget = Image.asset(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          print(
              'SystemResourceScreen (Zoom): Error loading asset image: $error');
          // Fallback to icon if asset also fails
          return Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.router,
                  size: 60,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'Image not available',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        },
      );
    } else {
      // Handle network images with interactive zoom
      imageWidget = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: isDark ? Colors.grey[800] : Colors.grey[200],
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: isDark ? Colors.blue[200] : Colors.blue[600],
                ),
                const SizedBox(height: 8),
                Text(
                  'Loading image...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print(
              'SystemResourceScreen (Zoom): Error loading cached image: $error');
          // Show default.png when network image fails
          return _buildInteractiveImage(
              'assets/mikrotik_product_images/default.png', isDark,
              isAsset: true);
        },
      );
    }

    // Wrap the image with InteractiveViewer for zoom capabilities
    return InteractiveViewer(
      panEnabled: true,
      scaleEnabled: true,
      minScale: 1.0,
      maxScale: 2.0,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: imageWidget,
        ),
      ),
    );
  }

  void _showZoomedImageDialog(BuildContext context, GlobalKey imageKey,
      String? boardName, bool isDark) {
    final displayName = RouterImageService.getRouterDisplayName(boardName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Fullscreen image with interactive zoom
              Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                color: isDark ? Colors.black87 : Colors.white,
                child: FutureBuilder<String>(
                  future: _getImageFuture(boardName),
                  builder: (context, snapshot) {
                    print(
                        'SystemResourceScreen (Zoom): FutureBuilder snapshot state: ${snapshot.connectionState}');
                    print(
                        'SystemResourceScreen (Zoom): FutureBuilder hasData: ${snapshot.hasData}');
                    print(
                        'SystemResourceScreen (Zoom): FutureBuilder data: ${snapshot.data}');
                    print(
                        'SystemResourceScreen (Zoom): FutureBuilder error: ${snapshot.error}');

                    if (snapshot.hasError) {
                      print(
                          'SystemResourceScreen (Zoom): Error loading router image: ${snapshot.error}');
                      return _buildInteractiveImage(
                          'assets/mikrotik_product_images/default.png', isDark,
                          isAsset: true);
                    }

                    // If we already have data, show it immediately without going through loading state
                    if (snapshot.hasData) {
                      print(
                          'SystemResourceScreen (Zoom): Loading cached image with URL: ${snapshot.data}');
                      return _buildInteractiveImage(snapshot.data!, isDark);
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      print(
                          'SystemResourceScreen (Zoom): Loading router image...');
                      return Container(
                        color: isDark ? Colors.grey[900] : Colors.grey[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color:
                                  isDark ? Colors.blue[200] : Colors.blue[600],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Loading image...',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    print(
                        'SystemResourceScreen (Zoom): No data or empty data, showing default image');
                    return _buildInteractiveImage(
                        'assets/mikrotik_product_images/default.png', isDark,
                        isAsset: true);
                  },
                ),
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white : Colors.black,
                    size: 30,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // Router name overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black54 : Colors.white70,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSystemOverview(
      Map<String, dynamic> resource, String identity, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSystemIdentity(identity, isDark),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildMetric(
                resource['board-name'] ?? '-',
                'Board Name',
                Icons.developer_board,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetric(
                resource['cpu-load'] != null
                    ? '${resource['cpu-load']}%'
                    : '0%',
                'CPU Load',
                Icons.speed,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetric(
                resource['cpu-count']?.toString() ?? '-',
                'CPU Count',
                Icons.confirmation_number,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetric(
                resource['cpu-frequency'] != null
                    ? '${resource['cpu-frequency']} MHz'
                    : '-',
                'CPU Frequency',
                Icons.memory,
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSystemIdentity(String identity, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.white, // Changed to pure white
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.router,
              color: isDark ? Colors.blue[200] : Colors.blue[600],
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                identity,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'System Identity',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String value, String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white, // Changed to pure white
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: isDark ? Colors.blue[200] : Colors.blue[600],
            size: 20,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildMetricsRow(
    String value1,
    String label1,
    IconData icon1,
    String value2,
    String label2,
    IconData icon2,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetric(value1, label1, icon1, isDark),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetric(value2, label2, icon2, isDark),
        ),
      ],
    );
  }

  void _showJsonDialog(BuildContext context, MikrotikProvider provider) {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    final resource = provider.resource ?? {};
    final license = provider.license ?? {};
    final identity = provider.identity ?? 'RouterOS';

    // Prepare JSON data
    final jsonData = {
      'identity': {'name': identity},
      'resource': resource,
      'license': license,
    };

    // Format JSON dengan indent
    final encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(jsonData);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 600,
            maxHeight: 700,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[900] : Colors.blue[700],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.code, color: Colors.white),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'JSON Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              // JSON Content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      jsonString,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              // Footer with copy button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: jsonString));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('JSON data copied to clipboard'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('System Resource'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Consumer<MikrotikProvider>(
              builder: (context, provider, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 15.0),
                  child: IconButton(
                    icon: const Icon(Icons.code),
                    tooltip: 'View JSON Data',
                    onPressed: () => _showJsonDialog(context, provider),
                  ),
                );
              },
            ),
          ],
        ),
        body: Consumer<MikrotikProvider>(
          builder: (context, provider, _) {
            final resource = provider.resource ?? {};
            final license = provider.license ?? {};
            final identity = provider.identity ?? 'RouterOS';

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: isDark ? 2 : 1,
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Router Image at the top
                        _buildRouterImage(resource['board-name'], isDark),
                        const SizedBox(height: 16),
                        // System Overview
                        _buildSystemOverview(resource, identity, isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (license.isNotEmpty) ...[
                  Card(
                    elevation: isDark ? 2 : 1,
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildResourceCard(
                              'Platform',
                              resource['platform'] ?? '-',
                              Icons.devices,
                              isDark),
                          _buildResourceCard(
                              'Uptime',
                              resource['uptime'] ?? '-',
                              Icons.access_time,
                              isDark),
                          _buildResourceCard(
                              'Version',
                              resource['version'] ?? '-',
                              Icons.verified,
                              isDark),
                          _buildResourceCard(
                              'Architecture',
                              resource['architecture-name'] ?? '-',
                              Icons.architecture,
                              isDark),
                          _buildResourceCard('CPU Model',
                              resource['cpu'] ?? '-', Icons.memory, isDark),
                          _buildResourceCard(
                            'Free Memory',
                            _formatMemory(resource['free-memory']),
                            Icons.sd_storage,
                            isDark,
                          ),
                          _buildResourceCard(
                            'Total Memory',
                            _formatMemory(resource['total-memory']),
                            Icons.sd_storage,
                            isDark,
                          ),
                          _buildResourceCard(
                            'Free HDD Space',
                            _formatMemory(resource['free-hdd-space']),
                            Icons.storage,
                            isDark,
                          ),
                          _buildResourceCard(
                            'Total HDD Space',
                            _formatMemory(resource['total-hdd-space']),
                            Icons.storage,
                            isDark,
                          ),
                          if (resource['build-time'] != null)
                            _buildResourceCard(
                              'Build Time',
                              resource['build-time'] ?? '-',
                              Icons.build,
                              isDark,
                            ),
                          if (resource['factory-software'] != null)
                            _buildResourceCard(
                              'Factory Software',
                              resource['factory-software'] ?? '-',
                              Icons.business,
                              isDark,
                            ),
                          if (resource['bad-blocks'] != null)
                            _buildResourceCard(
                              'Bad Blocks',
                              resource['bad-blocks'] ?? '0',
                              Icons.error_outline,
                              isDark,
                            ),
                          if (resource['write-sect-since-reboot'] != null)
                            _buildResourceCard(
                              'Write Sectors (Since Reboot)',
                              _formatNumber(
                                  resource['write-sect-since-reboot']),
                              Icons.edit,
                              isDark,
                            ),
                          if (resource['write-sect-total'] != null)
                            _buildResourceCard(
                              'Write Sectors (Total)',
                              _formatNumber(resource['write-sect-total']),
                              Icons.data_usage,
                              isDark,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: isDark ? 2 : 1,
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'License Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (license['software-id'] != null)
                            _buildResourceCard(
                              'Software ID',
                              license['software-id']?.toString() ?? '-',
                              Icons.vpn_key,
                              isDark,
                            ),
                          if (license['serial-number'] != null)
                            _buildResourceCard(
                              'Serial Number',
                              license['serial-number']?.toString() ?? '-',
                              Icons.confirmation_number,
                              isDark,
                            ),
                          if (license['nlevel'] != null)
                            _buildResourceCard(
                              'License Level',
                              _formatLicenseLevel(license['nlevel']),
                              Icons.star,
                              isDark,
                            ),
                          if (license['features'] != null &&
                              license['features'].toString().trim().isNotEmpty)
                            _buildLicenseFeaturesCard(
                              license['features'],
                              isDark,
                            ),
                          if (license['valid'] != null)
                            _buildResourceCard(
                              'License Status',
                              _formatLicenseStatus(license['valid']),
                              Icons.check_circle,
                              isDark,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

String _formatMemory(dynamic bytes) {
  if (bytes == null) return '-';
  double gb = int.parse(bytes.toString()) / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(1)} GiB';
}

String _formatNumber(dynamic number) {
  if (number == null) return '-';
  try {
    final num = int.parse(number.toString());
    // Format dengan separator ribuan
    return num.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  } catch (e) {
    return number.toString();
  }
}

String _formatLicenseLevel(dynamic level) {
  if (level == null) return '-';
  final levelStr = level.toString();
  // Map license levels to readable format
  switch (levelStr) {
    case '1':
      return 'Level 1 (Demo)';
    case '2':
      return 'Level 2';
    case '3':
      return 'Level 3';
    case '4':
      return 'Level 4';
    case '5':
      return 'Level 5';
    case '6':
      return 'Level 6';
    default:
      return 'Level $levelStr';
  }
}

String _formatLicenseStatus(dynamic valid) {
  if (valid == null) return '-';
  if (valid.toString().toLowerCase() == 'true' || valid.toString() == '1') {
    return 'Valid';
  } else {
    return 'Invalid';
  }
}
