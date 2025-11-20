<?php
// Script untuk memulihkan data billing dari backup
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
    
    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        // Tampilkan daftar backup yang tersedia
        $result = $conn->query("SHOW TABLES LIKE 'payments_backup_%'");
        $backups = [];
        while ($row = $result->fetch_array()) {
            $backups[] = $row[0];
        }
        
        echo json_encode([
            "success" => true,
            "payments_backups" => $backups
        ]);
    } else if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Pulihkan data billing dari backup
        $input = json_decode(file_get_contents("php://input"), true);
        $backup_table = $input['backup_table'] ?? '';
        $router_id = $input['router_id'] ?? '';
        
        if (empty($backup_table) || empty($router_id)) {
            throw new Exception("Backup table name and router_id are required");
        }
        
        // Validasi nama tabel backup
        if (!preg_match('/^payments_backup_\d{8}_\d{6}$/', $backup_table)) {
            throw new Exception("Invalid backup table name format");
        }
        
        // Mulai transaction
        $conn->begin_transaction();
        
        try {
            // Dapatkan mapping username ke user_id dari tabel users saat ini
            $userMapping = [];
            $userStmt = $conn->prepare("SELECT id, username FROM users WHERE router_id = ?");
            $userStmt->bind_param("s", $router_id);
            $userStmt->execute();
            $userResult = $userStmt->get_result();
            while ($row = $userResult->fetch_assoc()) {
                $userMapping[$row['username']] = $row['id'];
            }
            $userStmt->close();
            
            // Dapatkan data pembayaran dari backup
            $backupStmt = $conn->prepare("SELECT * FROM $backup_table WHERE router_id = ?");
            $backupStmt->bind_param("s", $router_id);
            $backupStmt->execute();
            $backupResult = $backupStmt->get_result();
            
            $restoredCount = 0;
            while ($row = $backupResult->fetch_assoc()) {
                // Periksa apakah user masih ada
                if (isset($userMapping[$row['username']])) {
                    // Update user_id dengan id yang benar
                    $userId = $userMapping[$row['username']];
                    
                    // Masukkan data pembayaran kembali
                    $insertStmt = $conn->prepare("INSERT INTO payments (router_id, user_id, amount, payment_date, payment_month, payment_year, method, note, created_by, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
                    $insertStmt->bind_param("ssdssiissss", 
                        $row['router_id'],
                        $userId,
                        $row['amount'],
                        $row['payment_date'],
                        $row['payment_month'],
                        $row['payment_year'],
                        $row['method'],
                        $row['note'],
                        $row['created_by'],
                        $row['created_at'],
                        $row['updated_at']
                    );
                    
                    if ($insertStmt->execute()) {
                        $restoredCount++;
                    }
                    $insertStmt->close();
                }
            }
            $backupStmt->close();
            
            // Commit transaction
            $conn->commit();
            
            echo json_encode([
                "success" => true,
                "message" => "Successfully restored $restoredCount payment records from backup",
                "restored_count" => $restoredCount
            ]);
        } catch (Exception $e) {
            // Rollback transaction jika ada error
            $conn->rollback();
            throw $e;
        }
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