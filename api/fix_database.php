<?php
// Script to fix database issues
require_once __DIR__ . '/config.php';

echo "Checking database structure...\n";

// Check if ppp_profile_pricing table exists
$table_check = $conn->query("SHOW TABLES LIKE 'ppp_profile_pricing'");
if ($table_check->num_rows == 0) {
    echo "Creating ppp_profile_pricing table...\n";
    $create_table = "
        CREATE TABLE IF NOT EXISTS ppp_profile_pricing (
          id INT AUTO_INCREMENT PRIMARY KEY,
          router_id VARCHAR(255) NOT NULL COMMENT 'Router ID untuk multi-router support',
          profile_name VARCHAR(100) NOT NULL COMMENT 'Nama profile PPP dari Mikrotik',
          price DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'Harga per bulan dalam Rupiah',
          description TEXT DEFAULT NULL COMMENT 'Deskripsi atau catatan tambahan',
          is_active TINYINT(1) DEFAULT 1 COMMENT 'Status aktif (1=aktif, 0=nonaktif)',
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          UNIQUE KEY unique_profile_router (router_id, profile_name),
          INDEX idx_router_id (router_id),
          INDEX idx_profile_name (profile_name),
          INDEX idx_is_active (is_active)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        COMMENT='Tabel untuk menyimpan harga per PPP Profile';
    ";
    if ($conn->query($create_table)) {
        echo "ppp_profile_pricing table created successfully.\n";
    } else {
        echo "Error creating ppp_profile_pricing table: " . $conn->error . "\n";
    }
} else {
    echo "ppp_profile_pricing table already exists.\n";
}

// Check if router_id column exists in users table
$column_check = $conn->query("SHOW COLUMNS FROM users LIKE 'router_id'");
if ($column_check->num_rows == 0) {
    echo "Adding router_id column to users table...\n";
    $alter_table = "ALTER TABLE users ADD COLUMN router_id VARCHAR(255) NOT NULL DEFAULT 'DEFAULT-ROUTER' AFTER id";
    if ($conn->query($alter_table)) {
        echo "router_id column added to users table.\n";
    } else {
        echo "Error adding router_id column: " . $conn->error . "\n";
    }
    
    // Add index for router_id
    $index_check = $conn->query("SHOW INDEX FROM users WHERE Key_name = 'idx_router_id'");
    if ($index_check->num_rows == 0) {
        $add_index = "ALTER TABLE users ADD INDEX idx_router_id (router_id)";
        if ($conn->query($add_index)) {
            echo "Index for router_id added.\n";
        } else {
            echo "Error adding index for router_id: " . $conn->error . "\n";
        }
    }
} else {
    echo "router_id column already exists in users table.\n";
}

// Check if router_id column exists in payments table
$payments_column_check = $conn->query("SHOW COLUMNS FROM payments LIKE 'router_id'");
if ($payments_column_check->num_rows == 0) {
    echo "Adding router_id column to payments table...\n";
    $alter_payments_table = "ALTER TABLE payments ADD COLUMN router_id VARCHAR(255) NOT NULL DEFAULT 'DEFAULT-ROUTER' AFTER id";
    if ($conn->query($alter_payments_table)) {
        echo "router_id column added to payments table.\n";
    } else {
        echo "Error adding router_id column to payments: " . $conn->error . "\n";
    }
    
    // Add index for router_id
    $payments_index_check = $conn->query("SHOW INDEX FROM payments WHERE Key_name = 'idx_router_id'");
    if ($payments_index_check->num_rows == 0) {
        $add_payments_index = "ALTER TABLE payments ADD INDEX idx_router_id (router_id)";
        if ($conn->query($add_payments_index)) {
            echo "Index for router_id added to payments table.\n";
        } else {
            echo "Error adding index for router_id to payments: " . $conn->error . "\n";
        }
    }
} else {
    echo "router_id column already exists in payments table.\n";
}

$conn->close();
echo "Database check completed.\n";
?>