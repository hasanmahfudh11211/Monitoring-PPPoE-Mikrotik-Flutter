import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/custom_snackbar.dart';
import 'package:image/image.dart' as img;
import '../services/api_service.dart';
import 'package:provider/provider.dart';
import '../providers/router_session_provider.dart';

class EditDataTambahanScreen extends StatefulWidget {
  final String username;
  final Map<String, dynamic> currentData;

  const EditDataTambahanScreen({
    Key? key,
    required this.username,
    required this.currentData,
  }) : super(key: key);

  @override
  State<EditDataTambahanScreen> createState() => _EditDataTambahanScreenState();
}

class _EditDataTambahanScreenState extends State<EditDataTambahanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _waController = TextEditingController();
  final _mapsController = TextEditingController();
  XFile? _pickedImage;
  bool _isLoading = false;
  String? _error;
  File? _imageFile;
  List<int>? _compressedImageBytes;
  String? _currentImageUrl;

  // State untuk ODP
  List<Map<String, dynamic>> _odpList = [];
  int? _selectedOdpId;
  bool _isLoadingOdp = true;

  @override
  void initState() {
    super.initState();
    // Inisialisasi data yang sudah ada
    _waController.text = widget.currentData['wa'] ?? '';
    _mapsController.text = widget.currentData['maps'] ?? '';
    _currentImageUrl = widget.currentData['foto'];

    // Set ODP yang sudah terpilih jika ada
    final odpId = widget.currentData['odp_id'];
    if (odpId != null) {
      // Pastikan tipenya int, jika dari json bisa jadi String atau int
      if (odpId is String) {
        _selectedOdpId = int.tryParse(odpId);
      } else if (odpId is int) {
        _selectedOdpId = odpId;
      }
    }

    _fetchOdpList();
  }

  @override
  void dispose() {
    _waController.dispose();
    _mapsController.dispose();
    super.dispose();
  }

  Future<void> _fetchOdpList() async {
    try {
      // Get router_id from RouterSessionProvider
      final routerId =
          Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null || routerId.isEmpty) {
        setState(() {
          _odpList = [];
          _isLoadingOdp = false;
        });
        return;
      }

      final response = await http.get(Uri.parse(
          '${ApiService.baseUrl}/odp_operations.php?router_id=$routerId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _odpList = List<Map<String, dynamic>>.from(data['odp_list']);
            // Pastikan _selectedOdpId valid, bandingkan sebagai integer
            if (_selectedOdpId != null &&
                !_odpList.any((odp) =>
                    int.tryParse(odp['id'].toString()) == _selectedOdpId)) {
              _selectedOdpId = null;
            }
          });
        }
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isLoadingOdp = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Compress image
        final File imageFile = File(image.path);
        final img.Image? originalImage =
            img.decodeImage(await imageFile.readAsBytes());

        if (originalImage != null) {
          // Resize and compress image
          final img.Image resizedImage = img.copyResize(
            originalImage,
            width: 800, // Max width
            height: (800 * originalImage.height / originalImage.width).round(),
          );

          final List<int> compressedBytes =
              img.encodeJpg(resizedImage, quality: 85);

          setState(() {
            _pickedImage = image;
            _imageFile = imageFile;
            _compressedImageBytes = compressedBytes;
          });
        }
      }
    } catch (e) {
      CustomSnackbar.show(
        context: context,
        message: 'Gagal memilih gambar',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    // Tampilkan dialog konfirmasi sebelum simpan
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final konfirmasi = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue.shade900 : Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.help_outline,
                    color: isDark ? Colors.blue.shade300 : Colors.blue,
                    size: 36),
              ),
              const SizedBox(height: 18),
              Text(
                'Konfirmasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah data sudah benar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white70 : Colors.grey[700],
                        side: BorderSide(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('BATAL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.grey[700],
                          )),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.blue.shade700
                            : Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('SIMPAN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          )),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (konfirmasi != true) return; // Jika batal, tidak lanjut simpan
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String? base64Image;
      if (_compressedImageBytes != null) {
        // Convert bytes to base64 string
        base64Image =
            'data:image/jpeg;base64,' + base64Encode(_compressedImageBytes!);
      }

      final routerId =
          Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null) {
        throw Exception('Silakan login router ulang');
      }
      final result = await ApiService.updateUserData(
        routerId: routerId,
        username: widget.username,
        wa: _waController.text.trim(),
        maps: _mapsController.text.trim(),
        foto: base64Image,
        odpId: _selectedOdpId,
      );

      if (!mounted) return;

      CustomSnackbar.show(
        context: context,
        message: 'Data berhasil diupdate',
        additionalInfo: 'Perubahan telah disimpan',
        isSuccess: true,
      );
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Gagal menyimpan perubahan',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Edit Data Tambahan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Card(
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
                        'Username: ${widget.username}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Form Fields
              Card(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // WhatsApp Field
                      TextFormField(
                        controller: _waController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Nomor WhatsApp',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          prefixIcon: Icon(
                            Icons.phone,
                            color: isDark ? Colors.blue.shade300 : Colors.blue,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  isDark ? Colors.blue.shade300 : Colors.blue,
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      // Maps Field
                      TextFormField(
                        controller: _mapsController,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Link Google Maps',
                          labelStyle: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          prefixIcon: Icon(
                            Icons.location_on,
                            color: isDark ? Colors.blue.shade300 : Colors.blue,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color:
                                  isDark ? Colors.blue.shade300 : Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ODP Dropdown
                      Text(
                        'Hubungkan ke ODP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _isLoadingOdp
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<int>(
                              value: _selectedOdpId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF2D2D2D)
                                    : Colors.white.withOpacity(0.9),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? Colors.blue.shade300
                                        : Colors.blue,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.device_hub,
                                  color: isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue,
                                ),
                                hintText: 'Pilih ODP',
                                hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              items: _odpList.map((odp) {
                                return DropdownMenuItem<int>(
                                  // Pastikan value adalah integer
                                  value: int.parse(odp['id'].toString()),
                                  child: Text(
                                    odp['name'],
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedOdpId = value;
                                });
                              },
                            ),

                      const SizedBox(height: 16),

                      // Image Picker
                      Text(
                        'Foto ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Column(
                          children: [
                            if (_pickedImage != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_pickedImage!.path),
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ] else if (_currentImageUrl != null &&
                                _currentImageUrl!.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _currentImageUrl!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey[300],
                                      child: Icon(
                                        Icons.error_outline,
                                        size: 50,
                                        color: isDark
                                            ? Colors.grey.shade400
                                            : Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _pickImage,
                              icon: Icon(
                                Icons.photo_camera,
                                color: isDark ? Colors.white : Colors.white,
                              ),
                              label: Text(
                                _pickedImage != null ||
                                        (_currentImageUrl != null &&
                                            _currentImageUrl!.isNotEmpty)
                                    ? 'Ganti Foto'
                                    : 'Pilih Foto',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.blue.shade700
                                    : Colors.blue.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveChanges,
                icon: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        Icons.save,
                        color: isDark ? Colors.white : Colors.white,
                      ),
                label: Text(
                  _isLoading ? 'MENYIMPAN...' : 'SIMPAN PERUBAHAN',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? Colors.blue.shade700 : Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
