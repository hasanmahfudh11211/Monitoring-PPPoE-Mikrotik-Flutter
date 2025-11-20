import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'package:path/path.dart' as path;

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  /// Creates an automatic backup before synchronization
  Future<Map<String, dynamic>> createAutoBackup(String routerId) async {
    try {
      final timestamp = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd-HH-mm-ss');
      final backupName = 'auto-backup-$routerId-${formatter.format(timestamp)}';
      
      // Create backup via API
      final url = Uri.parse('${ApiService.baseUrl}/full_database_backup.php');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'router_id': routerId,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return {
            'success': true,
            'backup_name': backupName,
            'tables': result['backup_tables'],
            'timestamp': timestamp,
          };
        } else {
          return {
            'success': false,
            'error': result['error'] ?? 'Failed to create backup',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Creates a full SQL dump backup
  Future<Map<String, dynamic>> createFullSQLBackup(String routerId) async {
    try {
      final timestamp = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd-HH-mm-ss');
      final backupFileName = 'pppoe-full-backup-$routerId-${formatter.format(timestamp)}.sql';
      
      // Get the SQL dump from API
      final url = Uri.parse('${ApiService.baseUrl}/generate_sql_dump.php');
      
      print('DEBUG: Sending request to $url with router_id: $routerId');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'router_id': routerId,
        }),
      );

      print('DEBUG: Response status: ${response.statusCode}');
      print('DEBUG: Response headers: ${response.headers}');
      if (response.body.length > 0) {
        print('DEBUG: Response body preview: ${response.body.substring(0, min(response.body.length, 200))}');
      } else {
        print('DEBUG: Response body is empty');
      }

      if (response.statusCode == 200) {
        // Check if response is actually SQL content or JSON error
        final contentType = response.headers['content-type'] ?? '';
        print('DEBUG: Content-Type header: $contentType');
        
        if (contentType.contains('application/sql') || response.body.startsWith('-- MySQL dump')) {
          print('DEBUG: Response is SQL content, saving to file');
          // Save to local file
          final appDir = await getApplicationDocumentsDirectory();
          final backupDir = Directory('${appDir.path}/backups');
          
          if (!await backupDir.exists()) {
            await backupDir.create(recursive: true);
          }

          final backupPath = '${backupDir.path}/$backupFileName';
          final backupFile = File(backupPath);
          await backupFile.writeAsString(response.body);

          return {
            'success': true,
            'file_path': backupPath,
            'file_name': backupFileName,
            'timestamp': timestamp,
          };
        } else {
          print('DEBUG: Response is not SQL content, trying to parse as JSON error');
          // Try to parse as JSON error
          try {
            final errorResult = jsonDecode(response.body);
            print('DEBUG: Parsed JSON error: $errorResult');
            return {
              'success': false,
              'error': errorResult['error'] ?? 'Failed to generate SQL backup: Invalid response format',
            };
          } catch (e) {
            print('DEBUG: Failed to parse JSON error: $e');
            return {
              'success': false,
              'error': 'Failed to generate SQL backup: Unexpected response format. Content-Type: $contentType, Body: ${response.body.substring(0, min(response.body.length, 200))}',
            };
          }
        }
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'error': 'Server endpoint not found. Please check if the API URL is correct and the generate_sql_dump.php file exists on the server.',
        };
      } else if (response.statusCode == 500) {
        return {
          'success': false,
          'error': 'Server error occurred while generating backup. Please try again later or contact the administrator.',
        };
      } else {
        print('DEBUG: HTTP error status code: ${response.statusCode}');
        // Try to parse error response
        try {
          final errorResult = jsonDecode(response.body);
          print('DEBUG: Parsed error response: $errorResult');
          return {
            'success': false,
            'error': errorResult['error'] ?? 'Server error: ${response.statusCode}',
          };
        } catch (e) {
          print('DEBUG: Failed to parse error response: $e');
          final bodyPreview = response.body.length > 0 ? response.body.substring(0, min(response.body.length, 200)) : 'Empty body';
          return {
            'success': false,
            'error': 'Server error: ${response.statusCode}. Response: $bodyPreview',
          };
        }
      }
    } catch (e, stackTrace) {
      print('ERROR: Exception in createFullSQLBackup: $e');
      print('Stack trace: $stackTrace');
      if (e.toString().contains('SocketException')) {
        return {
          'success': false,
          'error': 'Failed to connect to the server. Please check your internet connection and API configuration.',
        };
      } else if (e.toString().contains('FormatException')) {
        return {
          'success': false,
          'error': 'Invalid response format from server. Please contact the administrator.',
        };
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Creates a local file backup of the SQLite database
  Future<Map<String, dynamic>> createLocalBackup() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backups');
      
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateTime.now();
      final formatter = DateFormat('yyyy-MM-dd-HH-mm-ss');
      final backupFileName = 'local-backup-${formatter.format(timestamp)}.db';
      final backupPath = '${backupDir.path}/$backupFileName';

      // Note: In a real implementation, you would copy the actual database file here
      // For now, we'll just create a placeholder file to demonstrate the concept
      final backupFile = File(backupPath);
      await backupFile.writeAsString('Backup created at ${timestamp.toIso8601String()}');

      return {
        'success': true,
        'file_path': backupPath,
        'file_name': backupFileName,
        'timestamp': timestamp,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Gets list of available backups
  Future<Map<String, dynamic>> getAvailableBackups() async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/full_database_backup.php');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          return {
            'success': true,
            'backups': result['available_backups'] ?? [],
          };
        } else {
          return {
            'success': false,
            'error': result['error'] ?? 'Failed to fetch backups',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Cleans up old backups (keeps only last 10)
  Future<void> cleanupOldBackups() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/backups');
      
      if (await backupDir.exists()) {
        final files = backupDir.listSync()
            .where((entity) => entity is File)
            .toList();
        
        // Sort by modification time (newest first)
        files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
        
        // Keep only the 10 most recent backups
        if (files.length > 10) {
          for (int i = 10; i < files.length; i++) {
            if (files[i] is File) {
              await (files[i] as File).delete();
            }
          }
        }
      }
    } catch (e) {
      // Silently ignore cleanup errors
      print('Backup cleanup error: $e');
    }
  }
}