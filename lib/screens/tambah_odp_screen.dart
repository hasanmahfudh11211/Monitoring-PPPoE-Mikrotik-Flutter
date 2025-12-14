import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../providers/router_session_provider.dart';
import '../widgets/gradient_container.dart';

class TambahODPScreen extends StatefulWidget {
  final Map<String, dynamic>? odpToEdit;

  const TambahODPScreen({
    Key? key,
    this.odpToEdit,
  }) : super(key: key);

  @override
  State<TambahODPScreen> createState() => _TambahODPScreenState();
}

class _TambahODPScreenState extends State<TambahODPScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _mapsLinkController = TextEditingController();
  String _selectedType = 'splitter';
  String _selectedSplitterType = '1:8';
  final _ratioUsedController = TextEditingController();
  final _ratioTotalController = TextEditingController();
  bool _isLoading = false;
  bool _isUpdatingFromListener = false;

  @override
  void initState() {
    super.initState();
    if (widget.odpToEdit != null) {
      // Populate form with existing data
      _nameController.text = widget.odpToEdit!['name'].toString();
      _locationController.text = widget.odpToEdit!['location'].toString();
      _mapsLinkController.text =
          widget.odpToEdit!['maps_link']?.toString() ?? '';
      _selectedType = widget.odpToEdit!['type'].toString();
      if (_selectedType == 'splitter') {
        _selectedSplitterType = widget.odpToEdit!['splitter_type'].toString();
      } else {
        _ratioUsedController.text = widget.odpToEdit!['ratio_used'].toString();
        _ratioTotalController.text =
            widget.odpToEdit!['ratio_total'].toString();
      }
    }
    _ratioUsedController.addListener(_onRatioUsedChanged);
  }

  void _onRatioUsedChanged() {
    if (_isUpdatingFromListener) return;

    final usedValue = int.tryParse(_ratioUsedController.text);
    if (usedValue != null && usedValue >= 0 && usedValue <= 100) {
      final totalValue = 100 - usedValue;
      _isUpdatingFromListener = true;
      _ratioTotalController.text = totalValue.toString();
      _isUpdatingFromListener = false;
    } else if (_ratioUsedController.text.isEmpty) {
      _isUpdatingFromListener = true;
      _ratioTotalController.text = '';
      _isUpdatingFromListener = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _mapsLinkController.dispose();
    _ratioUsedController.removeListener(_onRatioUsedChanged);
    _ratioUsedController.dispose();
    _ratioTotalController.dispose();
    super.dispose();
  }

  Future<void> _saveODP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> data = {
        'name': _nameController.text,
        'location': _locationController.text,
        'maps_link': _mapsLinkController.text,
        'type': _selectedType,
      };

      if (_selectedType == 'splitter') {
        data['splitter_type'] = _selectedSplitterType;
      } else {
        // Safe parsing to prevent null pointer exceptions
        final ratioUsedText = _ratioUsedController.text.trim();
        final ratioTotalText = _ratioTotalController.text.trim();

        if (ratioUsedText.isNotEmpty && ratioTotalText.isNotEmpty) {
          data['ratio_used'] = int.tryParse(ratioUsedText) ?? 0;
          data['ratio_total'] = int.tryParse(ratioTotalText) ?? 0;
        } else {
          throw Exception('Ratio values cannot be empty');
        }
      }

      if (widget.odpToEdit != null) {
        data['id'] = widget.odpToEdit!['id'];
      }

      // Get router_id from RouterSessionProvider
      final routerId =
          Provider.of<RouterSessionProvider>(context, listen: false).routerId;
      if (routerId == null || routerId.isEmpty) {
        throw Exception('Router belum login. Silakan login dulu.');
      }

      final adminUsername =
          Provider.of<RouterSessionProvider>(context, listen: false).username;

      if (widget.odpToEdit != null) {
        // Update
        await ApiService.updateODP(
          routerId: routerId,
          id: int.parse(widget.odpToEdit!['id'].toString()),
          name: _nameController.text,
          location: _locationController.text,
          mapsLink: _mapsLinkController.text,
          type: _selectedType,
          splitterType:
              _selectedType == 'splitter' ? _selectedSplitterType : null,
          ratioUsed: _selectedType == 'ratio'
              ? int.tryParse(_ratioUsedController.text)
              : null,
          ratioTotal: _selectedType == 'ratio'
              ? int.tryParse(_ratioTotalController.text)
              : null,
          adminUsername: adminUsername,
        );
      } else {
        // Add
        await ApiService.addODP(
          routerId: routerId,
          name: _nameController.text,
          location: _locationController.text,
          mapsLink: _mapsLinkController.text,
          type: _selectedType,
          splitterType:
              _selectedType == 'splitter' ? _selectedSplitterType : null,
          ratioUsed: _selectedType == 'ratio'
              ? int.tryParse(_ratioUsedController.text)
              : null,
          ratioTotal: _selectedType == 'ratio'
              ? int.tryParse(_ratioTotalController.text)
              : null,
          adminUsername: adminUsername,
        );
      }

      // Mock response for compatibility with existing logic
      // ApiService throws exception on failure, so if we are here, it's success.
      const responseData = {'success': true};

      // Save response status: ${response.statusCode}
      // Save response body: ${response.body}

      if (!mounted) return;

      if (responseData['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ODP berhasil ${widget.odpToEdit != null ? 'diperbarui' : 'ditambahkan'}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(responseData['error'] ?? 'Gagal menyimpan ODP');
      }
    } catch (e) {
      // Error saving ODP: ${e.toString()}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            widget.odpToEdit != null ? 'Edit ODP' : 'Tambah ODP',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.odpToEdit != null) ...[
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
                          'Nama ODP: ${widget.odpToEdit!['name']}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lokasi: ${widget.odpToEdit!['location']}',
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Card(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Nama ODP',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color:
                                    isDark ? Colors.blue.shade300 : Colors.blue,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Nama ODP harus diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Lokasi',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color:
                                    isDark ? Colors.blue.shade300 : Colors.blue,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Lokasi harus diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _mapsLinkController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Link Google Maps',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            hintText: 'https://maps.google.com/...',
                            hintStyle: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color:
                                    isDark ? Colors.blue.shade300 : Colors.blue,
                              ),
                            ),
                          ),
                          keyboardType: TextInputType.url,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Link Google Maps harus diisi';
                            }
                            if (!Uri.parse(value).isAbsolute) {
                              return 'Masukkan URL yang valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          dropdownColor:
                              isDark ? const Color(0xFF2D2D2D) : Colors.white,
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'Tipe ODP',
                            labelStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(12)),
                              borderSide: BorderSide(
                                color:
                                    isDark ? Colors.blue.shade300 : Colors.blue,
                              ),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'splitter',
                              child: Text(
                                'Splitter',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'ratio',
                              child: Text(
                                'Ratio',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedType = value!);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tipe ODP harus dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        if (_selectedType == 'splitter')
                          DropdownButtonFormField<String>(
                            dropdownColor:
                                isDark ? const Color(0xFF2D2D2D) : Colors.white,
                            value: _selectedSplitterType,
                            decoration: InputDecoration(
                              labelText: 'Tipe Splitter',
                              labelStyle: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              border: OutlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.grey.shade700
                                      : Colors.grey.shade300,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(12)),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? Colors.blue.shade300
                                      : Colors.blue,
                                ),
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: '1:2',
                                  child: Text(
                                    '1:2',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  )),
                              DropdownMenuItem(
                                  value: '1:4',
                                  child: Text(
                                    '1:4',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  )),
                              DropdownMenuItem(
                                  value: '1:8',
                                  child: Text(
                                    '1:8',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  )),
                              DropdownMenuItem(
                                  value: '1:16',
                                  child: Text(
                                    '1:16',
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  )),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedSplitterType = value!);
                            },
                            validator: (value) {
                              if (_selectedType == 'splitter' &&
                                  (value == null || value.isEmpty)) {
                                return 'Tipe Splitter harus dipilih';
                              }
                              return null;
                            },
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ratioUsedController,
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Ratio 1',
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(12)),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(12)),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(12)),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.blue.shade300
                                            : Colors.blue,
                                      ),
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_selectedType == 'ratio') {
                                      if (value == null || value.isEmpty) {
                                        return 'Ratio terpakai harus diisi';
                                      }
                                      final number = int.tryParse(value);
                                      if (number == null ||
                                          number < 0 ||
                                          number > 100) {
                                        return 'Masukkan angka 0-100';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _ratioTotalController,
                                  enabled: false,
                                  style: TextStyle(
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Ratio 2',
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                    border: const OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(12)),
                                    ),
                                    fillColor: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey[200],
                                    filled: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (_selectedType == 'ratio') {
                                      if (value == null || value.isEmpty) {
                                        return 'Isi dari kiri';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveODP,
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
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isLoading
                      ? 'MENYIMPAN...'
                      : (widget.odpToEdit != null
                          ? 'SIMPAN PERUBAHAN'
                          : 'TAMBAH ODP'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    letterSpacing: 1.1,
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
            ),
          ),
        ),
      ),
    );
  }
}
