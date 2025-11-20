<?php
// Script untuk menambahkan user secara manual
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
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
        // Tambah user baru
        $input = json_decode(file_get_contents("php://input"), true);
        
        $router_id = $input['router_id'] ?? '';
        $username = $input['username'] ?? '';
        $password = $input['password'] ?? '';
        $profile = $input['profile'] ?? '';
        $wa = $input['wa'] ?? '';
        $maps = $input['maps'] ?? '';
        $foto = $input['foto'] ?? '';
        $tanggal_dibuat = $input['tanggal_dibuat'] ?? date('Y-m-d H:i:s');
        
        if (empty($router_id) || empty($username) || empty($password) || empty($profile)) {
            throw new Exception("router_id, username, password, and profile are required");
        }
        
        // Cek apakah user sudah ada
        $checkStmt = $conn->prepare("SELECT id FROM users WHERE router_id = ? AND username = ?");
        $checkStmt->bind_param("ss", $router_id, $username);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();
        
        if ($checkResult->num_rows > 0) {
            // Update user yang sudah ada
            $updateStmt = $conn->prepare("UPDATE users SET password = ?, profile = ?, wa = ?, maps = ?, foto = ?, tanggal_dibuat = ?, updated_at = NOW() WHERE router_id = ? AND username = ?");
            $updateStmt->bind_param("ssssssss", $password, $profile, $wa, $maps, $foto, $tanggal_dibuat, $router_id, $username);
            $updateStmt->execute();
            $affected = $updateStmt->affected_rows;
            $updateStmt->close();
            
            echo json_encode([
                "success" => true,
                "message" => "User updated successfully",
                "action" => "updated",
                "affected_rows" => $affected
            ]);
        } else {
            // Tambah user baru
            $insertStmt = $conn->prepare("INSERT INTO users (router_id, username, password, profile, wa, maps, foto, tanggal_dibuat) VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
            $insertStmt->bind_param("ssssssss", $router_id, $username, $password, $profile, $wa, $maps, $foto, $tanggal_dibuat);
            
            if ($insertStmt->execute()) {
                $insertId = $conn->insert_id;
                $insertStmt->close();
                
                echo json_encode([
                    "success" => true,
                    "message" => "User added successfully",
                    "action" => "inserted",
                    "user_id" => $insertId
                ]);
            } else {
                throw new Exception("Failed to add user: " . $conn->error);
            }
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