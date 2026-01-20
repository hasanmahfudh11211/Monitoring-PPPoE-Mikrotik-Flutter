import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent_plus/android_intent.dart';

import 'dart:convert';
import '../widgets/custom_snackbar.dart';
import 'package:image/image.dart' as img;
import '../services/api_service.dart';
import '../widgets/gradient_container.dart';
import 'package:provider/provider.dart';
import '../providers/router_session_provider.dart';

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
  final _alamatController = TextEditingController();
  final _redamanController = TextEditingController();
  final _tanggalTagihanController = TextEditingController();
  DateTime? _tanggalDibuat;
  bool _isLoading = false;
  String? _error;
  File? _imageFile;
  List<int>? _compressedImageBytes;

  @override
  void dispose() {
    _waController.dispose();
    _mapsController.dispose();
    _alamatController.dispose();
    _redamanController.dispose();
    _tanggalTagihanController.dispose();
    super.dispose();
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
                child: const Icon(Icons.help_outline,
                    color: Colors.blue, size: 36),
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
                      child: const Text('BATAL',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
                      child: const Text('SIMPAN',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
      // Get router_id from session
      final routerSession =
          Provider.of<RouterSessionProvider>(context, listen: false);
      final routerId = routerSession.routerId;

      if (routerId == null || routerId.isEmpty) {
        throw Exception('Router ID tidak ditemukan. Silakan login ulang.');
      }

      String? base64Image;
      if (_compressedImageBytes != null) {
        base64Image =
            'data:image/jpeg;base64,' + base64Encode(_compressedImageBytes!);
      }
      final adminUsername = routerSession.username;

      await ApiService.saveUser(
        routerId: routerId,
        username: widget.username,
        password: widget.password,
        profile: widget.profile,
        wa: _waController.text.trim(),
        maps: _mapsController.text.trim(),
        alamat: _alamatController.text.trim(),
        redaman: _redamanController.text.trim(),
        tanggalTagihan: _tanggalTagihanController.text.trim(),
        foto: base64Image,
        tanggalDibuat: (_tanggalDibuat ?? DateTime.now()).toIso8601String(),
        adminUsername: adminUsername,
      );

      if (!mounted) return;
      CustomSnackbar.show(
        context: context,
        message: 'Data tambahan berhasil disimpan',
        additionalInfo: 'Data telah disimpan ke server database',
        isSuccess: true,
      );
      Navigator.of(context).pop(true); // Kembali ke dashboard
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      setState(() => _error = errorMessage);
      CustomSnackbar.show(
        context: context,
        message: 'Gagal menyimpan data tambahan',
        additionalInfo: errorMessage,
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
                child: const Icon(Icons.help_outline,
                    color: Colors.blue, size: 36),
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
                      child: const Text('BATAL',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
                      child: const Text('OKE',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
    setState(() {
      _isLoading = true;
    });
    try {
      // Get router_id from session
      final routerSession =
          Provider.of<RouterSessionProvider>(context, listen: false);
      final routerId = routerSession.routerId;

      if (routerId == null || routerId.isEmpty) {
        throw Exception('Router ID tidak ditemukan. Silakan login ulang.');
      }

      String? base64Image;
      if (_compressedImageBytes != null) {
        base64Image =
            'data:image/jpeg;base64,' + base64Encode(_compressedImageBytes!);
      }
      final adminUsername = routerSession.username;

      await ApiService.saveUser(
        routerId: routerId,
        username: widget.username,
        password: widget.password,
        profile: widget.profile,
        wa: _waController.text.trim(),
        maps: _mapsController.text.trim(),
        foto: base64Image,
        tanggalDibuat: (_tanggalDibuat ?? DateTime.now()).toIso8601String(),
        adminUsername: adminUsername,
      );
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Terjadi kesalahan',
          additionalInfo: e.toString(),
          isSuccess: false,
        );
      }
      setState(() {
        _isLoading = false;
      });
      return;
    }
    setState(() {
      _isLoading = false;
    });
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
                child: const Icon(Icons.info_outline,
                    color: Colors.blue, size: 36),
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
                  child: const Text('OKE',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && mounted)
      Navigator.of(context).pop(true); // Kembali ke dashboard jika OKE
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

  Future<void> _openContactsApp() async {
    try {
      const intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'content://contacts/people/',
      );
      await intent.launch();
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Gagal membuka kontak',
          additionalInfo: e.toString(),
          isSuccess: false,
        );
      }
    }
  }

  Future<void> _openMaps() async {
    final Uri url = Uri.parse('https://maps.google.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Gagal membuka Maps',
          additionalInfo: 'Tidak dapat membuka aplikasi Maps',
          isSuccess: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
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
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor WA',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.phone),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.contacts),
                          onPressed: _openContactsApp,
                          tooltip: 'Buka Kontak',
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
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
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: 'Link Google Maps',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.map),
                        suffixIcon: IconButton(
                          icon: Image.asset(
                            'assets/pngimg.com - google_maps_pin_PNG26.png',
                            width: 24,
                            height: 24,
                          ),
                          onPressed: _openMaps,
                          tooltip: 'Buka Google Maps',
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Alamat Field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _alamatController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Lengkap',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.home),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Redaman Field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _redamanController,
                      decoration: const InputDecoration(
                        labelText: 'Redaman (dBm)',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.signal_cellular_alt),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tanggal Tagihan Field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _tanggalTagihanController,
                      readOnly: true,
                      onTap: () async {
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                          String formattedDate =
                              "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                          setState(() {
                            _tanggalTagihanController.text = formattedDate;
                          });
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tanggal Jatuh Tempo',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.calendar_today),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
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
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('SIMPAN SEKARANG',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
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
                      child: const Text('TAMBAH NANTI SAJA',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
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
