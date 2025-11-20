# Data Recovery Guide

This guide explains how to recover your data after accidental deletion during synchronization.

## What Happened

When you pressed "sinkron semua user" (sync all users), the synchronization process was executed with the `prune` parameter enabled. This caused the system to delete all existing users in your database that weren't in the data received from Mikrotik.

## Prevention Measures Implemented

We've added several safety measures to prevent this issue in the future:

1. **Safety checks in the sync script** - The system now prevents pruning when no data is received
2. **Warning system** - The system warns when a large amount of data would be deleted
3. **Automatic backups** - The system creates backups before potentially dangerous operations
4. **Enhanced error handling** - Better error messages to help identify issues

## Recovery Options

### Option 1: Restore from Automatic Backup

The system now automatically creates backups before potentially dangerous operations. To restore from a backup:

1. Check available backups:
   ```bash
   curl -X GET https://your-domain.com/api/restore_backup.php
   ```

2. Restore from a specific backup:
   ```bash
   curl -X POST https://your-domain.com/api/restore_backup.php \
        -H "Content-Type: application/json" \
        -d '{"router_id": "YOUR_ROUTER_ID", "backup_table": "users_backup_YYYYMMDD_HHMMSS"}'
   ```

### Option 2: Manual Data Entry

You can manually add users using the new API endpoint:

```bash
curl -X POST https://your-domain.com/api/add_user_manual.php \
     -H "Content-Type: application/json" \
     -d '{
       "router_id": "YOUR_ROUTER_ID",
       "username": "user123",
       "password": "password123",
       "profile": "10Mbps",
       "wa": "081234567890",
       "maps": "https://maps.google.com/?q=-6.200000,106.816666",
       "foto": "/path/to/photo.jpg",
       "tanggal_dibuat": "2025-11-10 10:00:00"
     }'
```

## Best Practices to Prevent Data Loss

1. **Regular backups** - Create regular backups of your database
2. **Test synchronization** - Always test sync operations with a small dataset first
3. **Monitor logs** - Check application logs for any warnings or errors
4. **Use caution with prune** - Only enable prune when you're certain about the data being synchronized

## Contact Support

If you need help recovering your data, please contact the development team with:
- The date and time when the data loss occurred
- Your router ID
- Any error messages you received