import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/custom_snackbar.dart';
import 'package:image/image.dart' as img;
import '../services/api_service.dart';

class TambahDataScreen extends StatefulWidget {
  final String username;
  final String password;
  final String profile;

  const TambahDataScreen({
    Key? key,
    required this.username,
    required this.password,
    required this.profile,
  }) : super(key: key);

  @override
  State<TambahDataScreen> createState() => _TambahDataScreenState();
}

class _TambahDataScreenState extends State<TambahDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _waController = TextEditingController();
  final _mapsController = TextEditingController();
  DateTime? _tanggalDibuat;
  bool _isLoading = false;
  String? _error;
  File? _imageFile;
  List<int>? _compressedImageBytes;

  @override
  void dispose() {
    _waController.dispose();
    _mapsController.dispose();
    super.dispose();
  }

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

  Future<void> _saveAdditionalData() async {
    if (!_formKey.currentState!.validate()) return;
    // Tampilkan dialog konfirmasi sebelum simpan
    final konfirmasi = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline, color: Colors.blue, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Konfirmasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Apakah data tambahan sudah benar?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('BATAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('SIMPAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
        base64Image = 'data:image/jpeg;base64,' + base64Encode(_compressedImageBytes!);
      }
      final userData = {
        'username': widget.username,
        'password': widget.password,
        'profile': widget.profile,
        'wa': _waController.text.trim(),
        'foto': base64Image ?? '',
        'maps': _mapsController.text.trim(),
        'tanggal_dibuat': (_tanggalDibuat ?? DateTime.now()).toIso8601String(),
      };
      final success = await saveUserToServer(userData);
      if (success) {
        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Data tambahan berhasil disimpan',
          additionalInfo: 'Data telah disimpan ke server database',
          isSuccess: true,
        );
        Navigator.of(context).pop(true); // Kembali ke dashboard
      } else {
        if (!mounted) return;
        CustomSnackbar.show(
          context: context,
          message: 'Gagal menyimpan data tambahan',
          additionalInfo: 'Silakan coba lagi atau hubungi administrator',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      CustomSnackbar.show(
        context: context,
        message: 'Terjadi kesalahan',
        additionalInfo: e.toString(),
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _tambahNantiSaja() async {
    // Konfirmasi dulu
    final konfirmasi = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.help_outline, color: Colors.blue, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Konfirmasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Apakah Anda yakin ingin menambah data nanti saja?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey.shade400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('BATAL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('OKE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (konfirmasi != true) return; // Jika batal, tidak lanjut
    // Kirim data ke server walaupun kosong
    setState(() { _isLoading = true; });
    try {
      String? base64Image;
      if (_compressedImageBytes != null) {
        base64Image = 'data:image/jpeg;base64,' + base64Encode(_compressedImageBytes!);
      }
      final userData = {
        'username': widget.username,
        'password': widget.password,
        'profile': widget.profile,
        'wa': _waController.text.trim(),
        'foto': base64Image ?? '',
        'maps': _mapsController.text.trim(),
        'tanggal_dibuat': (_tanggalDibuat ?? DateTime.now()).toIso8601String(),
      };
      final success = await saveUserToServer(userData);
      if (!success) {
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: 'Gagal menyimpan data tambahan',
            additionalInfo: 'Silakan coba lagi atau hubungi administrator',
            isSuccess: false,
          );
        }
        setState(() { _isLoading = false; });
        return;
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Terjadi kesalahan',
          additionalInfo: e.toString(),
          isSuccess: false,
        );
      }
      setState(() { _isLoading = false; });
      return;
    }
    setState(() { _isLoading = false; });
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
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
                  color: Colors.blue.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.info_outline, color: Colors.blue, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'Informasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Data tambahan bisa diisi atau diubah di menu edit data tambahan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('OKE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted) Navigator.of(context).pop(true); // Kembali ke dashboard jika OKE
    // Jika BATAL, tetap di halaman
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      File file = File(picked.path);
      final bytes = await file.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      if (image != null) {
        img.Image resized = img.copyResize(image, width: 1024);
        final compressedBytes = img.encodeJpg(resized, quality: 80);
        setState(() {
          _imageFile = File(picked.path); // Untuk preview
          _compressedImageBytes = compressedBytes;
        });
      } else {
        setState(() {
          _imageFile = File(picked.path);
          _compressedImageBytes = bytes;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Data Tambahan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // User Info Card
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
                        const Text(
                          'Informasi User',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildInfoRow('Username', widget.username),
                        const SizedBox(height: 8),
                        _buildInfoRow('Profile', widget.profile),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Nomor WA
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _waController,
                      decoration: const InputDecoration(
                        labelText: 'Nomor WA',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.phone),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Link Google Maps
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _mapsController,
                      decoration: const InputDecoration(
                        labelText: 'Link Google Maps',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.map),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Foto Rumah/Alat
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
                        const Text(
                          'Foto ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Pilih Foto'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade800,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (_imageFile != null)
                              SizedBox(
                                height: 60,
                                child: Image.file(_imageFile!),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tanggal dibuat
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.date_range),
                    title: Text(
                      _tanggalDibuat == null
                          ? 'Tanggal dibuat: (otomatis)'
                          : 'Tanggal dibuat: ${_tanggalDibuat!.toLocal().toString().split(' ')[0]}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _tanggalDibuat = picked;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Submit button
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                  onPressed: _isLoading ? null : _saveAdditionalData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                          : const Text('SIMPAN SEKARANG', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isLoading ? null : _tambahNantiSaja,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey.shade400),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                      child: const Text('TAMBAH NANTI SAJA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
} 