<?php
// Script untuk restore backup tabel users
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
        $result = $conn->query("SHOW TABLES LIKE 'users_backup_%'");
        $backups = [];
        while ($row = $result->fetch_array()) {
            $backups[] = $row[0];
        }
        
        echo json_encode([
            "success" => true,
            "backups" => $backups
        ]);
    } else if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        // Restore backup
        $input = json_decode(file_get_contents("php://input"), true);
        $backup_table = $input['backup_table'] ?? '';
        $router_id = $input['router_id'] ?? '';
        
        if (empty($backup_table) || empty($router_id)) {
            throw new Exception("Backup table name and router_id are required");
        }
        
        // Validasi nama tabel backup
        if (!preg_match('/^users_backup_\d{8}_\d{6}$/', $backup_table)) {
            throw new Exception("Invalid backup table name format");
        }
        
        // Mulai transaction
        $conn->begin_transaction();
        
        try {
            // Hapus data users yang ada untuk router_id ini
            $deleteStmt = $conn->prepare("DELETE FROM users WHERE router_id = ?");
            $deleteStmt->bind_param("s", $router_id);
            $deleteStmt->execute();
            $deleteStmt->close();
            
            // Restore dari backup
            $restoreStmt = $conn->prepare("INSERT INTO users (router_id, username, password, profile, wa, maps, foto, tanggal_dibuat, created_at, updated_at) SELECT router_id, username, password, profile, wa, maps, foto, tanggal_dibuat, created_at, updated_at FROM $backup_table WHERE router_id = ?");
            $restoreStmt->bind_param("s", $router_id);
            $restoreStmt->execute();
            $restoredCount = $restoreStmt->affected_rows;
            $restoreStmt->close();
            
            // Commit transaction
            $conn->commit();
            
            echo json_encode([
                "success" => true,
                "message" => "Successfully restored $restoredCount users from backup",
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