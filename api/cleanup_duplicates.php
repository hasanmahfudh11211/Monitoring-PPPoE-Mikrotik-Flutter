<?php
/**
 * Script untuk membersihkan duplikat user di database
 * Hanya menyisakan 1 record per (router_id, username) kombinasi
 * Menghapus duplikat dengan ID tertinggi (terbaru)
 */

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

try {
    require_once __DIR__ . '/config.php';
    
    if (!isset($conn) || $conn === null) {
        throw new Exception("Database connection failed");
    }
    
    // Cek apakah ada UNIQUE constraint (router_id, username)
    $checkConstraint = $conn->query("
        SELECT CONSTRAINT_NAME, TABLE_NAME 
        FROM information_schema.TABLE_CONSTRAINTS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'users' 
        AND CONSTRAINT_TYPE = 'UNIQUE'
        AND CONSTRAINT_NAME LIKE '%router%username%'
    ");
    
    if ($checkConstraint->num_rows == 0) {
        // Buat UNIQUE constraint jika belum ada
        $conn->query("
            ALTER TABLE users 
            DROP INDEX IF EXISTS idx_username,
            ADD UNIQUE KEY uniq_router_username (router_id, username)
        ");
    }
    
    // Cari semua duplikat (router_id + username yang sama)
    // Simpan ID tertinggi (terbaru) untuk setiap kombinasi
    $duplicatesQuery = "
        SELECT router_id, username, MAX(id) as keep_id, COUNT(*) as count
        FROM users
        WHERE router_id != '' AND username != ''
        GROUP BY router_id, username
        HAVING count > 1
    ";
    
    $result = $conn->query($duplicatesQuery);
    
    if (!$result) {
        throw new Exception("Query gagal: " . $conn->error);
    }
    
    $totalDuplicates = 0;
    $deletedCount = 0;
    $errors = [];
    
    while ($row = $result->fetch_assoc()) {
        $router_id = $row['router_id'];
        $username = $row['username'];
        $keep_id = $row['keep_id'];
        $count = $row['count'];
        $deleteCount = $count - 1; // Simpan 1, hapus sisanya
        
        $totalDuplicates += $deleteCount;
        
        // Hapus semua duplikat KECUALI yang ID-nya tertinggi
        $deleteStmt = $conn->prepare("
            DELETE FROM users 
            WHERE router_id = ? 
            AND username = ? 
            AND id < ?
        ");
        
        if (!$deleteStmt) {
            $errors[] = "Prepare DELETE gagal untuk '$username' (router: $router_id): " . $conn->error;
            continue;
        }
        
        $deleteStmt->bind_param("ssi", $router_id, $username, $keep_id);
        if ($deleteStmt->execute()) {
            $deletedCount += $deleteStmt->affected_rows;
        } else {
            $errors[] = "DELETE gagal untuk '$username' (router: $router_id): " . $deleteStmt->error;
        }
        
        $deleteStmt->close();
    }
    
    // Hitung total user setelah cleanup
    $totalUsers = $conn->query("SELECT COUNT(*) as total FROM users")->fetch_assoc()['total'];
    
    echo json_encode([
        "success" => true,
        "message" => "Cleanup selesai",
        "total_duplicates_found" => $totalDuplicates,
        "deleted_count" => $deletedCount,
        "total_users_remaining" => (int)$totalUsers,
        "errors" => $errors
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}

if (isset($conn) && $conn instanceof mysqli) { 
    $conn->close(); 
}
?>

