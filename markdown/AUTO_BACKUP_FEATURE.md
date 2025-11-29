# Automatic Backup Feature

This document explains the automatic backup feature that has been implemented to protect your data.

## Features Implemented

### 1. Automatic Backup Before Synchronization
- A full SQL backup is automatically created before every synchronization process
- This ensures that if something goes wrong during sync, you can restore your previous data
- The backup includes all user data, billing information, and other related data

### 2. Scheduled Backups
- **Daily Backup**: Runs automatically every day at 2:00 AM
- **Weekly Backup**: Runs automatically every Sunday at 3:00 AM
- These backups help protect against data loss over time

### 3. Manual Backup
- Users can create full SQL backups manually through the "Restore/Backup Database" screen
- Useful before making significant changes to the data

## How It Works

### Automatic Backup Process
1. Before synchronization begins, the system automatically creates a full SQL backup
2. The backup file is stored in the device's Download folder with a timestamped filename
3. If the synchronization fails, your data remains safe in the backup file

### Scheduled Backup Process
1. The system checks the current time daily
2. At 2:00 AM, a full SQL backup is automatically created
3. On Sundays at 3:00 AM, another full SQL backup is created
4. Old backups are automatically cleaned up (keeps only the 10 most recent)

### Manual Backup Process
1. Users can navigate to "Restore/Backup Database" screen
2. Click on "Backup Database" button to create a full SQL backup immediately
3. The backup file will be saved in the Download folder
4. A popup notification will inform about the backup status and automatic schedule

## Backup Storage

### Local SQL Backups
- Backups are stored as SQL dump files in the device's Download folder
- Format: `pppoe-full-backup-[router-id]-YYYY-MM-DD-HH-mm-ss.sql`
- Each backup includes all tables (users, payments, odp) for complete recovery

### Server-Side Backups
- Additional backups are stored on the server in separate tables with timestamped names
- Format: `users_backup_YYYYMMDD_HHMMSS`, `payments_backup_YYYYMMDD_HHMMSS`, etc.
- Provides redundancy in case local backups are lost

## Accessing Backups

### Through "Restore/Backup Database" Screen
1. Open the app and go to "Restore/Backup Database"
2. Tap on "Backup Database" to create a full SQL backup
3. The file will be saved in the Download folder
4. A popup will show backup status and inform about automatic schedule

### Automatic Process
- No user intervention required for scheduled backups
- Users are notified of backup success/failure through the app interface

## Data Protection

### What's Protected
- User data (username, password, profile)
- Additional user information (WhatsApp, maps, photos)
- Billing/payment information
- ODP (Optical Distribution Point) data
- All data is included in a single SQL file for easy restoration

### What's NOT Automatically Restored (Yet)
- Future versions will include full restore functionality
- Currently, backups are created but manual restoration would be required

## Best Practices

1. **Regular Manual Backups**: Create manual backups before making significant changes
2. **Check Backup Status**: Regularly verify that backups are being created successfully
3. **Verify Download Folder**: Ensure the Download folder has sufficient storage space
4. **Monitor Notifications**: Pay attention to backup success/failure notifications

## Troubleshooting

### Backup Not Created
- Check internet connection
- Verify server connectivity
- Ensure sufficient storage space on the device
- Check permissions for storage access

### Scheduled Backups Not Running
- Verify the app is running or has been opened recently
- Check device time settings
- Ensure the app has necessary permissions

### Backup File Not Found
- Check the Download folder on your device
- Verify storage permissions
- Check if the file was moved or deleted

## Future Improvements

1. **Full Restore Functionality**: One-click restore from backup
2. **Cloud Backup Storage**: Store backups in cloud services (Google Drive, Dropbox, etc.)
3. **Backup Encryption**: Encrypt backups for additional security
4. **Custom Backup Schedules**: Allow users to set custom backup times
5. **Backup Size Optimization**: Compress backup files to save storage space