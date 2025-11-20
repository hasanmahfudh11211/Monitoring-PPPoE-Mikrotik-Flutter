import 'lib/services/backup_service.dart';

void main() async {
  print('Testing backup functionality...');
  
  // Test with a sample router ID
  final routerId = 'test-router-id';
  
  try {
    print('Creating full SQL backup for router: $routerId');
    final result = await BackupService().createFullSQLBackup(routerId);
    
    if (result['success']) {
      print('Backup successful!');
      print('File path: ${result['file_path']}');
      print('File name: ${result['file_name']}');
    } else {
      print('Backup failed:');
      print('Error: ${result['error']}');
    }
  } catch (e) {
    print('Exception occurred:');
    print(e.toString());
  }
}