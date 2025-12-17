import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/gradient_container.dart';
import '../widgets/custom_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../main.dart';

class MessageTemplateScreen extends StatefulWidget {
  const MessageTemplateScreen({Key? key}) : super(key: key);

  @override
  State<MessageTemplateScreen> createState() => _MessageTemplateScreenState();
}

class _MessageTemplateScreenState extends State<MessageTemplateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _lunasController = TextEditingController();
  final TextEditingController _tagihanController = TextEditingController();
  String? _lunasImagePath;
  String? _tagihanImagePath;
  bool _isLoading = true;

  // Default Templates
  static const String defaultLunas = '''Halo [nama],

Terima kasih atas pembayaran Anda. Status pembayaran Anda sudah *LUNAS*.

*[periode]*
Total Pembayaran: [total]

Terima kasih telah menjadi pelanggan setia kami! 🙏''';

  static const String defaultTagihan = '''Assalamu'alaikum Pelanggan Yth,

Kami sampaikan bahwa tagihan anda sudah maksimal.
Segera lakukan pembayaran agar tidak otomatis terisolir.

*[periode]*

Pembayaran bisa melalui transfer ke:

*Rekening*
*BCA : ...*
*BRI : ...*
*BSI : ...*
*Dana : 085931564236*
Atas nama *Hasan Mahfudh*

Terimakasih''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lunasController.dispose();
    _tagihanController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _lunasController.text =
            prefs.getString('template_lunas') ?? defaultLunas;
        _tagihanController.text =
            prefs.getString('template_tagihan') ?? defaultTagihan;
        _lunasImagePath = prefs.getString('image_lunas');
        _tagihanImagePath = prefs.getString('image_tagihan');
      });
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Gagal memuat template',
          additionalInfo: e.toString(),
          isSuccess: false,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTemplates() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('template_lunas', _lunasController.text);
      await prefs.setString('template_tagihan', _tagihanController.text);
      if (_lunasImagePath != null) {
        await prefs.setString('image_lunas', _lunasImagePath!);
      } else {
        await prefs.remove('image_lunas');
      }
      if (_tagihanImagePath != null) {
        await prefs.setString('image_tagihan', _tagihanImagePath!);
      } else {
        await prefs.remove('image_tagihan');
      }

      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Template berhasil disimpan',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Gagal menyimpan template',
          additionalInfo: e.toString(),
          isSuccess: false,
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetToDefault() async {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Reset Template?',
            style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
            'Template akan dikembalikan ke pengaturan awal. Perubahan Anda akan hilang.',
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _lunasController.text = defaultLunas;
        _tagihanController.text = defaultTagihan;
        _lunasImagePath = null;
        _tagihanImagePath = null;
      });
      await _saveTemplates();
    }
  }

  Future<void> _pickImage(bool isLunas) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = path.basename(image.path);
        final savedImage =
            await File(image.path).copy('${appDir.path}/$fileName');

        setState(() {
          if (isLunas) {
            _lunasImagePath = savedImage.path;
          } else {
            _tagihanImagePath = savedImage.path;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: 'Gagal mengambil gambar',
          additionalInfo: e.toString(),
          isSuccess: false,
        );
      }
    }
  }

  void _removeImage(bool isLunas) {
    setState(() {
      if (isLunas) {
        _lunasImagePath = null;
      } else {
        _tagihanImagePath = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Template WhatsApp',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Reset ke Default',
              onPressed: _isLoading ? null : _resetToDefault,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Simpan',
              onPressed: _isLoading ? null : _saveTemplates,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Lunas'),
              Tab(text: 'Tagihan'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildEditor(
                            _lunasController, isDark, true, _lunasImagePath),
                        _buildEditor(_tagihanController, isDark, false,
                            _tagihanImagePath),
                      ],
                    ),
                  ),
                  _buildPlaceholderInfo(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildEditor(TextEditingController controller, bool isDark,
      bool isLunas, String? imagePath) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image Header Section
          Container(
            width: double.infinity,
            height: 120,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            ),
            child: imagePath != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => _removeImage(isLunas),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () => _pickImage(isLunas),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tambah Gambar Header',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              expands: true,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                height: 1.5,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Tulis template pesan di sini...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.white.withOpacity(0.5),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Kode Khusus (Placeholder):',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip('[nama]', 'Nama User', isDark),
              _buildChip('[total]', 'Total Tagihan', isDark),
              _buildChip('[bulan]', 'Bulan Tagihan', isDark),
              _buildChip('[periode]', 'Periode Lengkap', isDark),
              _buildChip('[admin]', 'Nama Admin', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String description, bool isDark) {
    return Tooltip(
      message: description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 12,
            fontFamily: 'Monospace',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
