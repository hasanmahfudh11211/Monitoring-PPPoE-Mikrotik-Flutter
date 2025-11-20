<?php
// Script untuk membuat backup lengkap database dalam format SQL
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
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
        // Buat backup lengkap
        $input = json_decode(file_get_contents("php://input"), true);
        $router_id = $input['router_id'] ?? '';
        
        if (empty($router_id)) {
            throw new Exception("router_id is required");
        }
        
        // Timestamp untuk nama backup
        $timestamp = date('Ymd_His');
        
        // Buat nama tabel backup dengan timestamp
        $users_backup_table = "users_backup_" . $timestamp;
        $payments_backup_table = "payments_backup_" . $timestamp;
        $odp_backup_table = "odp_backup_" . $timestamp;
        
        // Backup users
        $users_sql = "CREATE TABLE $users_backup_table AS 
                      SELECT *, '$timestamp' as backup_timestamp 
                      FROM users 
                      WHERE router_id = ?";
        $users_stmt = $conn->prepare($users_sql);
        $users_stmt->bind_param("s", $router_id);
        $users_stmt->execute();
        $users_stmt->close();
        
        // Backup payments dengan informasi username
        $payments_sql = "CREATE TABLE $payments_backup_table AS 
                         SELECT p.*, u.username, '$timestamp' as backup_timestamp 
                         FROM payments p 
                         LEFT JOIN users u ON p.user_id = u.id 
                         WHERE p.router_id = ?";
        $payments_stmt = $conn->prepare($payments_sql);
        $payments_stmt->bind_param("s", $router_id);
        $payments_stmt->execute();
        $payments_stmt->close();
        
        // Backup odp
        $odp_sql = "CREATE TABLE $odp_backup_table AS 
                    SELECT *, '$timestamp' as backup_timestamp 
                    FROM odp 
                    WHERE router_id = ?";
        $odp_stmt = $conn->prepare($odp_sql);
        $odp_stmt->bind_param("s", $router_id);
        $odp_stmt->execute();
        $odp_stmt->close();
        
        echo json_encode([
            "success" => true,
            "message" => "Full backup created successfully",
            "backup_tables" => [
                "users" => $users_backup_table,
                "payments" => $payments_backup_table,
                "odp" => $odp_backup_table
            ],
            "timestamp" => $timestamp
        ]);
    } else if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // Dapatkan daftar backup yang tersedia
        $result = $conn->query("SHOW TABLES LIKE '%_backup_%'");
        $backups = [];
        while ($row = $result->fetch_array()) {
            $backups[] = $row[0];
        }
        
        echo json_encode([
            "success" => true,
            "available_backups" => $backups
        ]);
    }
    
    $conn->close();
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}
?>