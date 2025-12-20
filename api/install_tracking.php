<?php
/**
 * Installer for Download Tracking Table
 * Run this script once to create the necessary table in your database.
 */

header('Content-Type: text/plain');

// Include database configuration
require_once __DIR__ . '/config.php';

if (!isset($conn)) {
    die("Error: Database connection not found in config.php");
}

echo "Starting installation...\n";

// Read SQL file
$sqlFile = __DIR__ . '/setup_download_logs.sql';
if (!file_exists($sqlFile)) {
    die("Error: SQL file not found at $sqlFile");
}

$sql = file_get_contents($sqlFile);

// Execute SQL
if ($conn->multi_query($sql)) {
    do {
        // Store first result set
        if ($result = $conn->store_result()) {
            $result->free();
        }
        // Check if there are more result sets
    } while ($conn->more_results() && $conn->next_result());
    
    echo "Success! Table 'download_logs' has been created/verified.\n";
    echo "You can now delete this file and setup_download_logs.sql if you wish.\n";
} else {
    echo "Error creating table: " . $conn->error . "\n";
}

$conn->close();
?>
