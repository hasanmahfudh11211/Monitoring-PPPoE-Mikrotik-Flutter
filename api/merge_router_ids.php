<?php
/**
 * Script untuk merge router_id dari format lama ke format baru
 * Misalnya: RB-RouterOS@192.168.99.1:80 -> 03FK-Q7XE (serial-number)
 * 
 * Usage: POST dengan JSON body:
 * {
 *   "old_router_id": "RB-RouterOS@192.168.99.1:80",
 *   "new_router_id": "03FK-Q7XE",
 *   "merge_strategy": "newest" // atau "oldest", "complete"
 * }
 */

ini_set('display_errors', 0);
error_reporting(E_ALL);

// Set error handler
set_error_handler(function($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// Function untuk return error response
function returnError($error, $httpCode = 500) {
    http_response_code($httpCode);
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode([
        "success" => false,
        "error" => $error,
        "timestamp" => date('Y-m-d H:i:s')
    ]);
    exit();
}

// Set headers
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
    require_once __DIR__ . '/config.php';
    
    if (!isset($conn) || $conn === null) {
        returnError("Database connection failed", 500);
    }
    
    if ($conn->connect_error) {
        returnError("Database connection error: " . $conn->connect_error, 500);
    }
    
    // Ambil input JSON
    $rawInput = file_get_contents("php://input");
    $data = json_decode($rawInput, true);
    
    if (json_last_error() !== JSON_ERROR_NONE) {
        returnError("Invalid JSON: " . json_last_error_msg(), 400);
    }
    
    if (!isset($data['old_router_id']) || !isset($data['new_router_id'])) {
        returnError("old_router_id dan new_router_id wajib diisi", 400);
    }
    
    $oldRouterId = trim($data['old_router_id']);
    $newRouterId = trim($data['new_router_id']);
    $mergeStrategy = isset($data['merge_strategy']) ? $data['merge_strategy'] : 'newest';
    
    if ($oldRouterId === '' || $newRouterId === '') {
        returnError("router_id tidak boleh kosong", 400);
    }
    
    if ($oldRouterId === $newRouterId) {
        returnError("old_router_id dan new_router_id tidak boleh sama", 400);
    }
    
    // Validasi merge strategy
    if (!in_array($mergeStrategy, ['newest', 'oldest', 'complete'])) {
        returnError("merge_strategy harus 'newest', 'oldest', atau 'complete'", 400);
    }
    
    $conn->begin_transaction();
    
    $usersMerged = 0;
    $usersDeleted = 0;
    $paymentsUpdated = 0;
    $odpUpdated = 0;
    $errors = [];
    
    // 1. Handle users table
    // Cari semua username yang ada di kedua router_id
    $duplicateQuery = "
        SELECT u1.id as old_id, u1.username, u1.created_at as old_created,
               u2.id as new_id, u2.created_at as new_created
        FROM users u1
        INNER JOIN users u2 ON u1.username = u2.username
        WHERE u1.router_id = ? AND u2.router_id = ?
    ";
    
    $stmt = $conn->prepare($duplicateQuery);
    if (!$stmt) {
        throw new Exception("Prepare query gagal: " . $conn->error);
    }
    $stmt->bind_param("ss", $oldRouterId, $newRouterId);
    $stmt->execute();
    $duplicateResult = $stmt->get_result();
    $duplicates = [];
    while ($row = $duplicateResult->fetch_assoc()) {
        $duplicates[] = $row;
    }
    $stmt->close();
    
    // Merge atau hapus duplikat berdasarkan strategy
    foreach ($duplicates as $dup) {
        try {
            $oldId = $dup['old_id'];
            $newId = $dup['new_id'];
            
            if ($mergeStrategy === 'newest') {
                // Hapus yang lama, keep yang baru
                $deleteStmt = $conn->prepare("DELETE FROM users WHERE id = ?");
                $deleteStmt->bind_param("i", $oldId);
                if ($deleteStmt->execute()) {
                    $usersDeleted++;
                }
                $deleteStmt->close();
            } else if ($mergeStrategy === 'oldest') {
                // Update yang baru ke router_id lama, lalu hapus yang baru
                $updateStmt = $conn->prepare("UPDATE users SET router_id = ? WHERE id = ?");
                $updateStmt->bind_param("si", $oldRouterId, $newId);
                $updateStmt->execute();
                $updateStmt->close();
                
                $deleteStmt = $conn->prepare("DELETE FROM users WHERE id = ?");
                $deleteStmt->bind_param("i", $newId);
                if ($deleteStmt->execute()) {
                    $usersDeleted++;
                }
                $deleteStmt->close();
            } else if ($mergeStrategy === 'complete') {
                // Merge data: ambil field yang tidak kosong dari keduanya, lalu hapus yang lama
                $mergeStmt = $conn->prepare("
                    UPDATE users u1
                    INNER JOIN users u2 ON u1.id = ? AND u2.id = ?
                    SET 
                        u1.wa = IFNULL(NULLIF(u1.wa, ''), u2.wa),
                        u1.maps = IFNULL(NULLIF(u1.maps, ''), u2.maps),
                        u1.foto = IFNULL(NULLIF(u1.foto, ''), u2.foto),
                        u1.profile = COALESCE(u1.profile, u2.profile),
                        u1.password = COALESCE(u1.password, u2.password),
                        u1.updated_at = NOW()
                ");
                $mergeStmt->bind_param("ii", $oldId, $newId);
                $mergeStmt->execute();
                $mergeStmt->close();
                
                $deleteStmt = $conn->prepare("DELETE FROM users WHERE id = ?");
                $deleteStmt->bind_param("i", $newId);
                if ($deleteStmt->execute()) {
                    $usersDeleted++;
                }
                $deleteStmt->close();
            }
        } catch (Exception $e) {
            $errors[] = "Error merge user {$dup['username']}: " . $e->getMessage();
        }
    }
    
    // Update semua user dengan router_id lama ke router_id baru (yang tidak duplikat)
    $updateQuery = "
        UPDATE users 
        SET router_id = ?, updated_at = NOW()
        WHERE router_id = ? 
        AND username NOT IN (
            SELECT username FROM (
                SELECT username FROM users WHERE router_id = ?
            ) AS temp
        )
    ";
    
    // Subquery tidak bisa langsung, jadi gunakan approach berbeda
    $updateQuery2 = "
        UPDATE users u1
        SET u1.router_id = ?, u1.updated_at = NOW()
        WHERE u1.router_id = ?
        AND NOT EXISTS (
            SELECT 1 FROM users u2 
            WHERE u2.username = u1.username 
            AND u2.router_id = ?
        )
    ";
    
    $updateStmt = $conn->prepare($updateQuery2);
    if (!$updateStmt) {
        throw new Exception("Prepare update query gagal: " . $conn->error);
    }
    $updateStmt->bind_param("sss", $newRouterId, $oldRouterId, $newRouterId);
    $updateStmt->execute();
    $usersMerged = $updateStmt->affected_rows;
    $updateStmt->close();
    
    // 2. Update payments (denormalized router_id)
    $paymentsQuery = "
        UPDATE payments p
        INNER JOIN users u ON p.user_id = u.id
        SET p.router_id = ?
        WHERE u.router_id = ? OR (p.router_id = ? AND p.router_id != '')
    ";
    $paymentsStmt = $conn->prepare($paymentsQuery);
    if (!$paymentsStmt) {
        throw new Exception("Prepare payments query gagal: " . $conn->error);
    }
    $paymentsStmt->bind_param("sss", $newRouterId, $newRouterId, $oldRouterId);
    $paymentsStmt->execute();
    $paymentsUpdated = $paymentsStmt->affected_rows;
    $paymentsStmt->close();
    
    // 3. Update ODP
    $odpQuery = "UPDATE odp SET router_id = ? WHERE router_id = ?";
    $odpStmt = $conn->prepare($odpQuery);
    if (!$odpStmt) {
        throw new Exception("Prepare ODP query gagal: " . $conn->error);
    }
    $odpStmt->bind_param("ss", $newRouterId, $oldRouterId);
    $odpStmt->execute();
    $odpUpdated = $odpStmt->affected_rows;
    $odpStmt->close();
    
    $conn->commit();
    
    $result = [
        "success" => true,
        "old_router_id" => $oldRouterId,
        "new_router_id" => $newRouterId,
        "merge_strategy" => $mergeStrategy,
        "stats" => [
            "users_merged" => $usersMerged,
            "users_deleted" => $usersDeleted,
            "duplicates_found" => count($duplicates),
            "payments_updated" => $paymentsUpdated,
            "odp_updated" => $odpUpdated
        ]
    ];
    
    if (!empty($errors)) {
        $result["warnings"] = $errors;
    }
    
    echo json_encode($result, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    if (isset($conn) && $conn->in_transaction) {
        $conn->rollback();
    }
    error_log("MERGE_ROUTER_ID_ERROR: " . $e->getMessage() . " | File: " . $e->getFile() . " | Line: " . $e->getLine());
    returnError("Fatal error: " . $e->getMessage(), 500);
} catch (Error $e) {
    if (isset($conn) && $conn->in_transaction) {
        $conn->rollback();
    }
    error_log("MERGE_ROUTER_ID_PHP_ERROR: " . $e->getMessage() . " | File: " . $e->getFile() . " | Line: " . $e->getLine());
    returnError("Fatal PHP error: " . $e->getMessage(), 500);
}

$conn->close();
?>





















