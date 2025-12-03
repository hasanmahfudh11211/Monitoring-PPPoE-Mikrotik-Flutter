import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:crypto/crypto.dart';

/// Client untuk menangani komunikasi low-level dengan Mikrotik API (Port 8728/8729)
class MikrotikApiClient {
  Socket? _socket;
  bool _isLoggedIn = false;
  bool _enableLogging = false;

  // Buffer untuk menampung data dari stream socket
  final List<int> _buffer = [];
  Completer<void>? _dataSignal;
  StreamSubscription? _subscription;

  // Lock untuk mencegah race condition saat multiple request
  final List<Completer<void>> _requestQueue = [];

  bool get isLoggedIn => _isLoggedIn;

  /// Membuka koneksi ke router
  Future<void> connect(String host, int port,
      {bool enableLogging = false}) async {
    _enableLogging = enableLogging;
    try {
      _log('Connecting to $host:$port...');
      _socket =
          await Socket.connect(host, port, timeout: const Duration(seconds: 5));

      // Listen ke stream socket dan masukkan data ke buffer
      _subscription = _socket!.listen(
        (data) {
          _buffer.addAll(data);
          if (_dataSignal != null && !_dataSignal!.isCompleted) {
            _dataSignal!.complete();
          }
        },
        onError: (e) {
          _log('Socket error: $e');
          close();
        },
        onDone: () {
          _log('Socket closed by remote');
          close();
        },
      );

      _log('Connected!');
    } catch (e) {
      throw Exception('Gagal terhubung ke $host:$port : $e');
    }
  }

  /// Menutup koneksi
  void close() {
    _subscription?.cancel();
    _socket?.destroy();
    _socket = null;
    _isLoggedIn = false;
    _buffer.clear();
    _log('Connection closed.');
  }

  void _log(String message) {
    if (_enableLogging) {
      print('[MKT-API] $message');
    }
  }

  /// Login ke router
  Future<void> login(String username, String password) async {
    if (_socket == null)
      throw Exception('Socket belum terhubung. Panggil connect() dulu.');

    // 1. Coba login metode baru (Post-6.43)
    _log('Attempting login...');
    var response =
        await talk(['/login', '=name=$username', '=password=$password']);

    var ret =
        response.firstWhere((r) => r.containsKey('!ret'), orElse: () => {});
    var trap =
        response.firstWhere((r) => r.containsKey('!trap'), orElse: () => {});

    if (trap.isNotEmpty) {
      if (!trap.containsKey('message') ||
          !trap['message']!.contains('cannot use md5')) {
        throw Exception('Login gagal: ${trap['message']}');
      }
    }

    var done =
        response.firstWhere((r) => r.containsKey('!done'), orElse: () => {});
    if (done.isNotEmpty && ret.isEmpty && trap.isEmpty) {
      _isLoggedIn = true;
      _log('Login successful (Plain/New Method).');
      return;
    }

    // 2. Jika dapat challenge (ret), lakukan Legacy Login (MD5)
    if (ret.containsKey('!ret')) {
      String challenge = ret['!ret']!;
      _log('Got challenge: $challenge. Switching to Legacy Login (MD5).');

      var md5Str = _createHash(password, challenge);
      response =
          await talk(['/login', '=name=$username', '=response=00$md5Str']);

      done =
          response.firstWhere((r) => r.containsKey('!done'), orElse: () => {});
      if (done.isNotEmpty) {
        _isLoggedIn = true;
        _log('Login successful (Legacy MD5).');
        return;
      }
    }

    throw Exception('Login gagal. Username atau password mungkin salah.');
  }

  /// Mengirim perintah (sentence) dan menunggu balasan lengkap
  Future<List<Map<String, String>>> talk(List<String> command) async {
    if (_socket == null) throw Exception('Not connected');

    // --- Locking Mechanism ---
    // Buat completer untuk request ini
    final myCompleter = Completer<void>();

    // Jika ada request lain yang sedang berjalan, tunggu giliran
    if (_requestQueue.isNotEmpty) {
      await _requestQueue.last.future;
    }

    // Masukkan diri sendiri ke antrian (sebagai penanda sedang berjalan)
    _requestQueue.add(myCompleter);

    try {
      // --- Critical Section Start ---

      // Kirim command
      for (var word in command) {
        _sendWord(word);
      }
      _sendWord(''); // End of sentence

      // Baca response sampai ketemu !done
      List<Map<String, String>> replies = [];
      Map<String, String> currentReply = {};

      while (true) {
        String line = await _readWord();

        if (line.isEmpty) {
          if (currentReply.isNotEmpty) {
            replies.add(Map.from(currentReply));
            if (currentReply.containsKey('!done')) {
              break;
            }
            currentReply = {};
          }
          continue;
        }

        if (line.startsWith('!')) {
          currentReply[line] = '';
        } else if (line.startsWith('=')) {
          var parts = line.substring(1).split('=');
          if (parts.length >= 2) {
            var key = parts[0];
            var value = parts.sublist(1).join('=');
            currentReply[key] = value;
          } else {
            currentReply[parts[0]] = '';
          }
        } else {
          currentReply['raw_data'] = line;
        }
      }

      return replies;
      // --- Critical Section End ---
    } finally {
      // Selesai, lepaskan lock dan beritahu antrian berikutnya
      _requestQueue.remove(myCompleter);
      if (!myCompleter.isCompleted) {
        myCompleter.complete();
      }
    }
  }

  // --- Helper Internal ---

  void _sendWord(String word) {
    List<int> bytes = utf8.encode(word);
    _writeLen(bytes.length);
    _socket!.add(bytes);
    if (_enableLogging) print('>> $word');
  }

  void _writeLen(int len) {
    if (len < 0x80) {
      _socket!.add([len]);
    } else if (len < 0x4000) {
      len |= 0x8000;
      _socket!.add([(len >> 8) & 0xFF, len & 0xFF]);
    } else if (len < 0x200000) {
      len |= 0xC00000;
      _socket!.add([(len >> 16) & 0xFF, (len >> 8) & 0xFF, len & 0xFF]);
    } else if (len < 0x10000000) {
      len |= 0xE0000000;
      _socket!.add([
        (len >> 24) & 0xFF,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF
      ]);
    } else {
      _socket!.add([
        0xF0,
        (len >> 24) & 0xFF,
        (len >> 16) & 0xFF,
        (len >> 8) & 0xFF,
        len & 0xFF
      ]);
    }
  }

  Future<String> _readWord() async {
    int len = await _readLen();
    if (len == 0) return '';

    List<int> bytes = await _readBytes(len);
    var str = utf8.decode(bytes);
    if (_enableLogging) print('<< $str');
    return str;
  }

  Future<int> _readLen() async {
    int b = (await _readBytes(1))[0];

    if ((b & 0x80) == 0) {
      return b;
    } else if ((b & 0xC0) == 0x80) {
      int b2 = (await _readBytes(1))[0];
      return ((b & 0x3F) << 8) | b2;
    } else if ((b & 0xE0) == 0xC0) {
      var rest = await _readBytes(2);
      return ((b & 0x1F) << 16) | (rest[0] << 8) | rest[1];
    } else if ((b & 0xF0) == 0xE0) {
      var rest = await _readBytes(3);
      return ((b & 0x0F) << 24) | (rest[0] << 16) | (rest[1] << 8) | rest[2];
    } else if (b == 0xF0) {
      var rest = await _readBytes(4);
      return (rest[0] << 24) | (rest[1] << 16) | (rest[2] << 8) | rest[3];
    }
    return 0;
  }

  /// Membaca n bytes dari buffer
  Future<List<int>> _readBytes(int n) async {
    while (_buffer.length < n) {
      if (_socket == null) throw Exception('Socket closed');
      // Buat completer baru jika belum ada atau sudah selesai
      if (_dataSignal == null || _dataSignal!.isCompleted) {
        _dataSignal = Completer<void>();
      }
      // Tunggu data masuk dengan timeout
      try {
        await _dataSignal!.future.timeout(const Duration(seconds: 5));
      } catch (e) {
        throw Exception('Timeout waiting for data from router');
      }
    }

    // Ambil n bytes dari depan buffer
    List<int> result = _buffer.sublist(0, n);
    _buffer.removeRange(0, n);
    return result;
  }

  String _createHash(String password, String challenge) {
    List<int> challengeBytes = [];
    for (int i = 0; i < challenge.length; i += 2) {
      challengeBytes.add(int.parse(challenge.substring(i, i + 2), radix: 16));
    }
    var msg = [0] + utf8.encode(password) + challengeBytes;
    var digest = md5.convert(msg);
    return digest.toString();
  }
}
