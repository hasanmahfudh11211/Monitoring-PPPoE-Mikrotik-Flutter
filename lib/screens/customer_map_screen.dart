import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/router_session_provider.dart';
import '../services/api_service.dart';
import '../widgets/gradient_container.dart';
import 'dart:ui';

// Custom TileProvider using CachedNetworkImage
class CachedTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return CachedNetworkImageProvider(
      getTileUrl(coordinates, options),
    );
  }
}

// Data class to hold parsed location data
class UserLocationData {
  final LatLng point;
  final Map<String, dynamic> user;

  UserLocationData({required this.point, required this.user});
}

// Top-level function for background processing
List<UserLocationData> _parseUserLocations(List<dynamic> users) {
  final List<UserLocationData> results = [];

  // Regex for standard "lat,lng" format
  final simpleRegex = RegExp(r'([-+]?\d{1,2}\.\d+),\s*([-+]?\d{1,3}\.\d+)');

  for (var user in users) {
    final mapsLink = user['maps'] as String?;
    if (mapsLink != null && mapsLink.isNotEmpty) {
      LatLng? latLng;
      try {
        // 1. Try parsing standard "lat,lng" format
        final simpleMatch = simpleRegex.firstMatch(mapsLink);

        if (simpleMatch != null) {
          final lat = double.parse(simpleMatch.group(1)!);
          final lng = double.parse(simpleMatch.group(2)!);
          latLng = LatLng(lat, lng);
        } else {
          // 2. Try parsing Google Maps URL
          final uri = Uri.tryParse(mapsLink);
          if (uri != null) {
            final qParam = uri.queryParameters['q'];
            if (qParam != null) {
              final qMatch = simpleRegex.firstMatch(qParam);
              if (qMatch != null) {
                final lat = double.parse(qMatch.group(1)!);
                final lng = double.parse(qMatch.group(2)!);
                latLng = LatLng(lat, lng);
              }
            }

            if (latLng == null) {
              // 3. Try parsing from path
              final pathMatch = simpleRegex.firstMatch(uri.path);
              if (pathMatch != null) {
                final lat = double.parse(pathMatch.group(1)!);
                final lng = double.parse(pathMatch.group(2)!);
                latLng = LatLng(lat, lng);
              }
            }
          }
        }
      } catch (e) {
        // Ignore parsing errors in background
      }

      if (latLng != null) {
        results.add(UserLocationData(point: latLng, user: user));
      }
    }
  }
  return results;
}

class CustomerMapScreen extends StatefulWidget {
  const CustomerMapScreen({super.key});

  @override
  State<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class _CustomerMapScreenState extends State<CustomerMapScreen> {
  // Data State
  List<UserLocationData> _allUserLocations = [];
  bool _isLoading = true;
  String? _error;

  // Filter State
  String _searchQuery = '';
  String? _selectedPackage;
  final TextEditingController _searchController = TextEditingController();

  // Map State
  final MapController _mapController = MapController();
  int _mapType = 1; // 0 = Normal, 1 = Satellite
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final routerId =
          Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null) throw Exception('Router ID not found');

      // Fetch raw data
      final users =
          await ApiService.fetchAllUsersWithPayments(routerId: routerId);

      // Process in background isolate
      final parsedLocations = await compute(_parseUserLocations, users);

      if (mounted) {
        setState(() {
          _allUserLocations = parsedLocations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Filter Logic
  List<Marker> get _filteredMarkers {
    return _allUserLocations.where((data) {
      final user = data.user;
      final name = (user['name'] ?? '').toString().toLowerCase();
      final username = (user['username'] ?? '').toString().toLowerCase();
      final price = (user['price'] ?? '').toString();

      // Search Filter
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          username.contains(_searchQuery.toLowerCase());

      // Package Filter
      final matchesPackage =
          _selectedPackage == null || price == _selectedPackage;

      return matchesSearch && matchesPackage;
    }).map((data) {
      return Marker(
        point: data.point,
        width: 50,
        height: 50,
        child: GestureDetector(
          onTap: () => _showUserDetail(data.user, data.point),
          child: _buildCustomMarker(),
        ),
      );
    }).toList();
  }

  // Get unique package prices for filter chips
  List<String> get _availablePackages {
    final packages = _allUserLocations
        .map((e) => e.user['price'] as String?)
        .where((e) => e != null && e.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();
    packages.sort();
    return packages;
  }

  Widget _buildCustomMarker() {
    // Optimized marker: const Icon where possible
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.location_on,
          color: Colors.red.shade700,
          size: 50,
        ),
        Positioned(
          top: 8,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person,
              size: 14,
              color: Colors.red.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are denied')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location permissions are permanently denied, we cannot request permissions.')),
        );
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15.0,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  Future<void> _launchMapsUrl(LatLng point) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${point.latitude},${point.longitude}');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch Google Maps')),
        );
      }
    }
  }

  void _showUserDetail(Map<String, dynamic> user, LatLng point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E).withOpacity(0.9)
                    : Colors.white.withOpacity(0.9),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person,
                            color: Colors.blue.shade700, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['username'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              user['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _detailRow(Icons.money, 'Paket', user['price'] ?? '-'),
                  const Divider(height: 24),
                  _detailRow(Icons.map, 'Alamat', user['alamat'] ?? '-'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Tutup'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _launchMapsUrl(point);
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Ambil Rute'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black54),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _tileUrl {
    if (_mapType == 1) {
      // Google Satellite Hybrid
      return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
    }
    // Google Maps Normal
    return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If full screen, show only the map stack
    if (_isFullScreen) {
      return Scaffold(
        body: _buildMapStack(isFullScreen: true),
      );
    }

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Customer Map',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(
                      'Error: $_error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : Column(
                    children: [
                      // Search & Filter Section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Glassmorphism Search Bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withOpacity(0.1)
                                        : Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      hintText: 'Cari nama atau username...',
                                      hintStyle: TextStyle(
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        color: Colors.white,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Modern Filter Chips
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    label: 'Semua',
                                    isSelected: _selectedPackage == null,
                                    onTap: () {
                                      setState(() {
                                        _selectedPackage = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ..._availablePackages.map((pkg) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: _buildFilterChip(
                                        label: pkg,
                                        isSelected: _selectedPackage == pkg,
                                        onTap: () {
                                          setState(() {
                                            _selectedPackage =
                                                _selectedPackage == pkg
                                                    ? null
                                                    : pkg;
                                          });
                                        },
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Boxed Map Section
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: _buildMapStack(isFullScreen: false),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.8)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? Colors.blue.shade300
                    : Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildMapStack({required bool isFullScreen}) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _allUserLocations.isNotEmpty
                ? _allUserLocations.first.point
                : const LatLng(-6.200000, 106.816666), // Jakarta default
            initialZoom: 13.0,
          ),
          children: [
            TileLayer(
              urlTemplate: _tileUrl,
              userAgentPackageName: 'com.example.mikrotik_monitor',
              // Use CachedTileProvider for caching
              tileProvider: CachedTileProvider(),
              // Increase panBuffer for smoother panning (pre-load tiles)
              panBuffer: 2,
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 120, // Increased for better performance
                size: const Size(40, 40),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(50),
                maxZoom: 15,
                markers: _filteredMarkers,
                builder: (context, markers) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.blue,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Center(
                      child: Text(
                        markers.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        // Controls
        Positioned(
          bottom: 30,
          right: 20,
          child: Column(
            children: [
              // Full Screen Toggle
              _buildGlassButton(
                icon: isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                onPressed: () {
                  setState(() {
                    _isFullScreen = !_isFullScreen;
                  });
                },
              ),
              const SizedBox(height: 10),
              // My Location Button
              _buildGlassButton(
                icon: Icons.my_location,
                onPressed: _getCurrentLocation,
              ),
              const SizedBox(height: 10),
              // Layer Toggle
              _buildGlassButton(
                icon: _mapType == 0 ? Icons.layers : Icons.satellite_alt,
                onPressed: () {
                  setState(() {
                    _mapType = _mapType == 0 ? 1 : 0;
                  });
                },
              ),
              const SizedBox(height: 10),
              // Zoom In
              _buildGlassButton(
                icon: Icons.add,
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    currentZoom + 1,
                  );
                },
              ),
              const SizedBox(height: 10),
              // Zoom Out
              _buildGlassButton(
                icon: Icons.remove,
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    currentZoom - 1,
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
