import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/mikrotik_provider.dart';
import '../providers/router_session_provider.dart';
import '../services/log_service.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/gradient_container.dart';
import 'tambah_data_screen.dart';

class TambahScreen extends StatefulWidget {
  const TambahScreen({Key? key}) : super(key: key);

  @override
  State<TambahScreen> createState() => _TambahScreenState();
}

class _TambahScreenState extends State<TambahScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _selectedProfile;
  bool _isLoading = false;
  bool _isLoadingProfiles = true;
  String? _error;
  bool _obscurePassword = true;
  List<String> _profiles = [];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      setState(() {
        _error = null;
        _isLoadingProfiles = true;
      });

      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final profiles = await provider.service.getPPPProfile();

      if (mounted) {
        setState(() {
          _profiles = profiles
              .map((profile) => profile['name'].toString())
              .toList()
            ..sort();

          if (_profiles.isNotEmpty) {
            _selectedProfile = _profiles.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal memuat profile: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfiles = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<bool> _confirmClearForm() async {
    if (_usernameController.text.isEmpty && _passwordController.text.isEmpty) {
      return true;
    }

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Bersihkan Form?'),
            content:
                const Text('Apakah Anda yakin ingin membersihkan form ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('BATAL'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('YA'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _clearForm() {
    _usernameController.clear();
    _passwordController.clear();
    if (_profiles.isNotEmpty) {
      setState(() => _selectedProfile = _profiles.first);
    }
  }

  Future<void> _addUser() async {
    setState(() => _error = null);

    if (!_formKey.currentState!.validate()) return;
    if (_selectedProfile == null) {
      setState(() => _error = 'Profile harus dipilih');
      CustomSnackbar.show(
        context: context,
        message: 'Profile harus dipilih',
        additionalInfo: 'Silakan pilih profile untuk user baru',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<MikrotikProvider>(context, listen: false);
      final mikrotikData = {
        'name': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
        'profile': _selectedProfile!,
        'service': 'pppoe',
      };
      await provider.service.addPPPSecret(mikrotikData);

      // Log activity
      final routerSession =
          Provider.of<RouterSessionProvider>(context, listen: false);
      LogService.logActivity(
        username: routerSession.username ?? 'System',
        action: LogService.ACTION_ADD_USER,
        routerId: routerSession.routerId ?? '',
        details: 'added ppp secret: ${_usernameController.text.trim()}',
      );

      if (!mounted) return;

      // Tampilkan dialog sukses besar di tengah layar
      bool _showPassword = false;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Dialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success icon container
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  const Text(
                    'User berhasil ditambahkan',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // User info container
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Username: ${_usernameController.text.trim()}',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Password: ' +
                                    (_showPassword
                                        ? _passwordController.text.trim()
                                        : '••••••••'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                  _showPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 18),
                              tooltip:
                                  _showPassword ? 'Sembunyikan' : 'Tampilkan',
                              onPressed: () => setState(
                                  () => _showPassword = !_showPassword),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Profile: ${_selectedProfile}',
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
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
            ),
          ),
        ),
      );

      // Setelah OKE, navigasi ke TambahDataScreen
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TambahDataScreen(
            username: _usernameController.text.trim(),
            password: _passwordController.text.trim(),
            profile: _selectedProfile!,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true); // Kembali ke dashboard dengan refresh
    } catch (e) {
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      setState(() => _error = errorMessage);
      CustomSnackbar.show(
        context: context,
        message: 'Gagal menambahkan user',
        additionalInfo: errorMessage,
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
    return GradientContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'Tambah User PPP',
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
                // Username field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.person),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Username tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password field
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: InputBorder.none,
                        prefixIcon: const Icon(Icons.lock),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Profile dropdown
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: _isLoadingProfiles
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: _selectedProfile,
                            decoration: const InputDecoration(
                              labelText: 'Profile',
                              border: InputBorder.none,
                              prefixIcon: Icon(Icons.category),
                              contentPadding:
                                  EdgeInsets.symmetric(horizontal: 16),
                            ),
                            items: _profiles.map((String profile) {
                              return DropdownMenuItem<String>(
                                value: profile,
                                child: Text(profile),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedProfile = newValue;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Profile harus dipilih';
                              }
                              return null;
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

                // Buttons row
                Row(
                  children: [
                    // Clear form button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                if (await _confirmClearForm()) {
                                  _clearForm();
                                }
                              },
                        icon: const Icon(Icons.clear),
                        label: const Text('BERSIHKAN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Submit button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _addUser,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.add),
                        label: _isLoading
                            ? const Text('MENAMBAHKAN...')
                            : const Text('TAMBAH'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 4,
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
      ),
    );
  }
}
