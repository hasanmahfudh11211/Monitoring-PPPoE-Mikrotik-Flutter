<?php
// Script untuk menghasilkan file SQL dump lengkap
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Koneksi ke database via config terpusat
    require_once __DIR__ . '/config.php';
    
    // Cek koneksi database
    if (!isset($conn) || $conn === null) {
        throw new Exception("Database connection failed");
    }
    
    // Test koneksi
    if ($conn->connect_error) {
        throw new Exception("Database connection error: " . $conn->connect_error);
    }
    
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents("php://input"), true);
        $router_id = $input['router_id'] ?? '';
        
        if (empty($router_id)) {
            throw new Exception("router_id is required");
        }
        
        // Set headers untuk download file SQL
        header('Content-Type: application/sql');
        header('Content-Disposition: attachment; filename="pppoe_backup_' . date('Y-m-d_H-i-s') . '.sql"');
        
        // Output SQL header
        echo "-- MySQL dump for PPPoE Monitor\n";
        echo "-- Generated on " . date('Y-m-d H:i:s') . "\n";
        echo "-- Router ID: $router_id\n";
        echo "\n";
        echo "SET SQL_MODE = \"NO_AUTO_VALUE_ON_ZERO\";\n";
        echo "START TRANSACTION;\n";
        echo "SET time_zone = \"+00:00\";\n";
        echo "\n";
        
        // Backup ODP table
        echo "--\n";
        echo "-- Table structure for table `odp`\n";
        echo "--\n\n";
        $odpResult = $conn->query("SHOW CREATE TABLE odp");
        if ($row = $odpResult->fetch_row()) {
            echo $row[1] . ";\n\n";
        }
        
        echo "--\n";
        echo "-- Dumping data for table `odp`\n";
        echo "--\n\n";
        $odpData = $conn->prepare("SELECT * FROM odp WHERE router_id = ?");
        $odpData->bind_param("s", $router_id);
        $odpData->execute();
        $odpResult = $odpData->get_result();
        
        if ($odpResult->num_rows > 0) {
            echo "INSERT INTO `odp` (`id`, `name`, `location`, `maps_link`, `type`, `splitter_type`, `ratio_used`, `ratio_total`, `created_at`, `updated_at`, `router_id`) VALUES\n";
            $odpRows = [];
            while ($row = $odpResult->fetch_assoc()) {
                $values = [];
                foreach ($row as $value) {
                    if ($value === null) {
                        $values[] = 'NULL';
                    } else {
                        $values[] = "'" . $conn->real_escape_string($value) . "'";
                    }
                }
                $odpRows[] = "(" . implode(", ", $values) . ")";
            }
            echo implode(",\n", $odpRows) . ";\n\n";
        }
        
        // Backup users table
        echo "--\n";
        echo "-- Table structure for table `users`\n";
        echo "--\n\n";
        $usersResult = $conn->query("SHOW CREATE TABLE users");
        if ($row = $usersResult->fetch_row()) {
            echo $row[1] . ";\n\n";
        }
        
        echo "--\n";
        echo "-- Dumping data for table `users`\n";
        echo "--\n\n";
        $usersData = $conn->prepare("SELECT * FROM users WHERE router_id = ?");
        $usersData->bind_param("s", $router_id);
        $usersData->execute();
        $usersResult = $usersData->get_result();
        
        if ($usersResult->num_rows > 0) {
            echo "INSERT INTO `users` (`id`, `router_id`, `username`, `password`, `profile`, `wa`, `maps`, `foto`, `tanggal_dibuat`, `odp_id`, `created_at`, `updated_at`) VALUES\n";
            $usersRows = [];
            while ($row = $usersResult->fetch_assoc()) {
                $values = [];
                foreach ($row as $value) {
                    if ($value === null) {
                        $values[] = 'NULL';
                    } else {
                        $values[] = "'" . $conn->real_escape_string($value) . "'";
                    }
                }
                $usersRows[] = "(" . implode(", ", $values) . ")";
            }
            echo implode(",\n", $usersRows) . ";\n\n";
        }
        
        // Backup payments table
        echo "--\n";
        echo "-- Table structure for table `payments`\n";
        echo "--\n\n";
        $paymentsResult = $conn->query("SHOW CREATE TABLE payments");
        if ($row = $paymentsResult->fetch_row()) {
            echo $row[1] . ";\n\n";
        }
        
        echo "--\n";
        echo "-- Dumping data for table `payments`\n";
        echo "--\n\n";
        $paymentsData = $conn->prepare("SELECT * FROM payments WHERE router_id = ?");
        $paymentsData->bind_param("s", $router_id);
        $paymentsData->execute();
        $paymentsResult = $paymentsData->get_result();
        
        if ($paymentsResult->num_rows > 0) {
            echo "INSERT INTO `payments` (`id`, `router_id`, `user_id`, `amount`, `payment_date`, `payment_month`, `payment_year`, `method`, `note`, `created_by`, `created_at`, `updated_at`) VALUES\n";
            $paymentsRows = [];
            while ($row = $paymentsResult->fetch_assoc()) {
                $values = [];
                foreach ($row as $value) {
                    if ($value === null) {
                        $values[] = 'NULL';
                    } else {
                        $values[] = "'" . $conn->real_escape_string($value) . "'";
                    }
                }
                $paymentsRows[] = "(" . implode(", ", $values) . ")";
            }
            echo implode(",\n", $paymentsRows) . ";\n\n";
        }
        
        // Output SQL footer
        echo "COMMIT;\n";
        
        $conn->close();
        exit();
    } else {
        // Return error for non-POST requests
        header("Content-Type: application/json; charset=UTF-8");
        http_response_code(405);
        echo json_encode([
            "success" => false,
            "error" => "Method not allowed. Use POST method."
        ]);
    }
    
} catch (Exception $e) {
    // If headers not sent yet, send JSON error
    if (!headers_sent()) {
        header("Content-Type: application/json; charset=UTF-8");
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "error" => $e->getMessage()
        ]);
    } else {
        echo "\n-- Error: " . $e->getMessage();
    }
}
?>