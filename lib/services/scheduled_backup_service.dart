import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'backup_service.dart';
import 'package:flutter/foundation.dart';

class ScheduledBackupService {
  static final ScheduledBackupService _instance = ScheduledBackupService._internal();
  factory ScheduledBackupService() => _instance;
  ScheduledBackupService._internal();

  Timer? _dailyBackupTimer;
  Timer? _weeklyBackupTimer;

  /// Initialize scheduled backups
  void initializeScheduledBackups() {
    // Cancel any existing timers
    _dailyBackupTimer?.cancel();
    _weeklyBackupTimer?.cancel();

    // Schedule daily backup at 2 AM
    _scheduleDailyBackup();
    
    // Note: Weekly backup has been removed as per user request
    // Only daily backups will be performed
  }

  /// Schedule daily backup at 2 AM
  void _scheduleDailyBackup() {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 2, 0); // 2 AM
    
    // If it's already past 2 AM today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    
    final duration = scheduledTime.difference(now);
    
    _dailyBackupTimer = Timer(duration, () async {
      await _performScheduledBackup('daily');
      // Schedule next daily backup
      _dailyBackupTimer = Timer(const Duration(days: 1), () async {
        await _performScheduledBackup('daily');
        // Continue scheduling daily backups
        _scheduleDailyBackup();
      });
    });
  }

  /// Schedule weekly backup on Sundays at 3 AM
  // This method has been commented out as per user request to remove weekly backups
  /*
  void _scheduleWeeklyBackup() {
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 3, 0); // 3 AM
    
    // Adjust to next Sunday
    final daysUntilSunday = (DateTime.sunday - scheduledTime.weekday) % 7;
    if (daysUntilSunday == 0 && scheduledTime.isBefore(now)) {
      // If today is Sunday but past 3 AM, schedule for next Sunday
      scheduledTime = scheduledTime.add(const Duration(days: 7));
    } else {
      scheduledTime = scheduledTime.add(Duration(days: daysUntilSunday));
    }
    
    final duration = scheduledTime.difference(now);
    
    _weeklyBackupTimer = Timer(duration, () async {
      await _performScheduledBackup('weekly');
      // Schedule next weekly backup (7 days later)
      _weeklyBackupTimer = Timer(const Duration(days: 7), () async {
        await _performScheduledBackup('weekly');
        // Continue scheduling weekly backups
        _scheduleWeeklyBackup();
      });
    });
  }
  */

  /// Perform scheduled backup
  Future<void> _performScheduledBackup(String backupType) async {
    try {
      // Get router ID from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final routerId = prefs.getString('last_router_id');
      
      if (routerId != null && routerId.isNotEmpty) {
        final result = await BackupService().createFullSQLBackup(routerId);
        
        if (kDebugMode) {
          print('Scheduled $backupType backup result: $result');
        }
        
        // Clean up old backups
        await BackupService().cleanupOldBackups();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Scheduled backup error: $e');
      }
    }
  }

  /// Cancel all scheduled backups
  void cancelScheduledBackups() {
    _dailyBackupTimer?.cancel();
    _weeklyBackupTimer?.cancel();
  }
}