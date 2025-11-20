<?php
ini_set('display_errors', 0);
error_reporting(E_ALL);

// Set error handler untuk catch semua error
set_error_handler(function($severity, $message, $file, $line) {
    throw new ErrorException($message, 0, $severity, $file, $line);
});

// Function untuk return error response dengan format yang benar
function returnError($error, $httpCode = 500) {
    http_response_code($httpCode);
    header("Content-Type: application/json; charset=UTF-8");
    echo json_encode([
        "success" => false,
        "error" => $error,
        "debug" => [
            "timestamp" => date('Y-m-d H:i:s'),
            "php_error" => error_get_last()
        ]
    ]);
    exit();
}

// Function untuk membuat backup tabel users
function createUsersBackup($conn, $router_id) {
    $backup_table = "users_backup_" . date('Ymd_His');
    $sql = "CREATE TABLE $backup_table AS SELECT * FROM users WHERE router_id = ?";
    $stmt = $conn->prepare($sql);
    if ($stmt) {
        $stmt->bind_param("s", $router_id);
        $result = $stmt->execute();
        $stmt->close();
        return $result ? $backup_table : false;
    }
    return false;
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
    // Koneksi ke database via config terpusat
    require_once __DIR__ . '/config.php';
    require_once __DIR__ . '/router_id_helper.php';
    
    // Cek koneksi database
    if (!isset($conn) || $conn === null) {
        returnError("Database connection failed", 500);
    }
    
    // Test koneksi
    if ($conn->connect_error) {
        returnError("Database connection error: " . $conn->connect_error, 500);
    }
    
    // Ambil raw input untuk debug
    $rawInput = file_get_contents("php://input");
    
    // Debug: log raw input
    error_log("SYNC_DEBUG: Raw input length=" . strlen($rawInput));

    // Decode JSON dengan error handling
    $data = json_decode($rawInput, true);

    // Check JSON decode errors
    if (json_last_error() !== JSON_ERROR_NONE) {
        returnError("Invalid JSON: " . json_last_error_msg() . " | Preview: " . substr($rawInput, 0, 200), 400);
    }

    if (!isset($data['ppp_users']) || !is_array($data['ppp_users'])) {
        returnError("No PPP user data received or invalid format", 400);
    }

    // Validasi router_id dari body
    $router_id = isset($data['router_id']) ? trim($data['router_id']) : '';
    if ($router_id === '') {
        returnError("router_id required", 400);
    }

    // Keamanan: Cek jika prune diaktifkan tapi data kosong
    $doPrune = isset($data['prune']) ? (bool)$data['prune'] : false;
    if ($doPrune && (empty($data['ppp_users']) || count($data['ppp_users']) == 0)) {
        returnError("PERINGATAN KEAMANAN: Operasi prune dibatalkan karena tidak ada data yang diterima. Ini bisa menyebabkan kehilangan data.", 400);
    }

    // Keamanan: Cek jika prune diaktifkan dan data yang diterima sangat sedikit
    if ($doPrune && count($data['ppp_users']) < 5) {
        // Hitung total user yang ada saat ini untuk router_id ini
        $countStmt = $conn->prepare("SELECT COUNT(*) as total FROM users WHERE router_id = ?");
        $countStmt->bind_param("s", $router_id);
        $countStmt->execute();
        $countResult = $countStmt->get_result();
        $currentCount = 0;
        if ($row = $countResult->fetch_assoc()) {
            $currentCount = (int)$row['total'];
        }
        $countStmt->close();
        
        // Jika akan menghapus lebih dari 80% data, beri peringatan
        if ($currentCount > 10 && count($data['ppp_users']) < ($currentCount * 0.2)) {
            // Buat backup sebelum melakukan prune yang berpotensi menghapus banyak data
            $backup_table = createUsersBackup($conn, $router_id);
            error_log("SYNC_WARNING: Backup dibuat di tabel $backup_table sebelum prune besar-besaran.");
            
            returnError("PERINGATAN KEAMANAN: Operasi prune dibatalkan karena akan menghapus terlalu banyak data (" . ($currentCount - count($data['ppp_users'])) . " dari $currentCount user). Backup dibuat di tabel: $backup_table", 400);
        }
    }

    $added = 0;
    $updated = 0;
    $skipped = 0; // jumlah data dilewati (mis. username kosong)
    $pruned = 0; // jumlah data dihapus saat pembersihan
    $errors = [];

    // Simpan daftar username yang dikirim untuk opsi prune
    $incomingUsernames = [];

    foreach ($data['ppp_users'] as $index => $user) {
        try {
            // Validate user data structure
            if (!is_array($user)) {
                $errors[] = "User at index $index is not an array";
                continue;
            }
            
            $username = isset($user['name']) ? trim($user['name']) : '';
            $password = isset($user['password']) ? trim($user['password']) : '';
            $profile = isset($user['profile']) ? trim($user['profile']) : '';
            
            if (empty($username)) {
                $skipped++; // lewati username kosong
                continue;
            }
            
            // Simpan ke list incoming untuk kemungkinan prune (gunakan username asli, sebelum escape)
            if (!empty($username)) { $incomingUsernames[] = $username; }

            // Strategi: UPDATE hanya field yang diterima dari Mikrotik, pertahankan field lainnya yang sudah ada
            // 1) Cek apakah user sudah ada
            $checkStmt = $conn->prepare("SELECT id, wa, maps, foto, tanggal_dibuat FROM users WHERE router_id = ? AND username = ?");
            if (!$checkStmt) {
                $errors[] = "Prepare SELECT gagal untuk '$username': " . $conn->error;
                continue;
            }
            $checkStmt->bind_param("ss", $router_id, $username);
            $checkStmt->execute();
            $checkResult = $checkStmt->get_result();
            
            if ($checkResult->num_rows > 0) {
                // User sudah ada, ambil data tambahan yang sudah dimasukkan sebelumnya
                $existingUser = $checkResult->fetch_assoc();
                $checkStmt->close();
                
                // Gunakan data tambahan yang sudah ada (WhatsApp, maps, foto, tanggal_dibuat)
                $wa = $existingUser['wa'];
                $maps = $existingUser['maps'];
                $foto = $existingUser['foto'];
                $tanggal_dibuat = $existingUser['tanggal_dibuat'];
                
                // Update hanya field dasar dari Mikrotik, PERTAHANKAN field tambahan yang sudah ada
                $updateStmt = $conn->prepare("UPDATE users SET password = ?, profile = ?, wa = ?, maps = ?, foto = ?, tanggal_dibuat = ?, updated_at = NOW() WHERE router_id = ? AND username = ?");
                if (!$updateStmt) {
                    $errors[] = "Prepare UPDATE gagal untuk '$username': " . $conn->error;
                    continue;
                }
                $updateStmt->bind_param("ssssssss", $password, $profile, $wa, $maps, $foto, $tanggal_dibuat, $router_id, $username);
                $updateStmt->execute();
                $updated++;
                $updateStmt->close();
            } else {
                // 2) User baru, lakukan INSERT dengan data dasar dari Mikrotik
                $checkStmt->close();
                $insertStmt = $conn->prepare("INSERT INTO users (router_id, username, password, profile, wa, maps, foto, tanggal_dibuat) VALUES (?, ?, ?, ?, '', '', '', NOW())");
                if (!$insertStmt) {
                    $errors[] = "Prepare INSERT gagal untuk '$username': " . $conn->error;
                    continue;
                }
                $insertStmt->bind_param("ssss", $router_id, $username, $password, $profile);
                if ($insertStmt->execute()) {
                    $added++;
                } else if ($insertStmt->errno == 1062) {
                    // Balapan antar request: sudah ada barisnya → update sekali lagi dengan mempertahankan data tambahan
                    $retry = $conn->prepare("SELECT wa, maps, foto, tanggal_dibuat FROM users WHERE router_id = ? AND username = ?");
                    if ($retry) {
                        $retry->bind_param("ss", $router_id, $username);
                        if ($retry->execute()) {
                            $retryResult = $retry->get_result();
                            if ($retryResult->num_rows > 0) {
                                $existingUser = $retryResult->fetch_assoc();
                                $wa = $existingUser['wa'];
                                $maps = $existingUser['maps'];
                                $foto = $existingUser['foto'];
                                $tanggal_dibuat = $existingUser['tanggal_dibuat'];
                                
                                // Update dengan mempertahankan data tambahan
                                $updateRetry = $conn->prepare("UPDATE users SET password = ?, profile = ?, wa = ?, maps = ?, foto = ?, tanggal_dibuat = ?, updated_at = NOW() WHERE router_id = ? AND username = ?");
                                if ($updateRetry) {
                                    $updateRetry->bind_param("ssssssss", $password, $profile, $wa, $maps, $foto, $tanggal_dibuat, $router_id, $username);
                                    if ($updateRetry->execute()) {
                                        $updated++;
                                    }
                                    $updateRetry->close();
                                }
                            }
                        }
                        $retry->close();
                    }
                } else {
                    $errors[] = "Insert gagal untuk '$username': " . $insertStmt->error . " (Errno: " . $insertStmt->errno . ")";
                }
                $insertStmt->close();
            }

        } catch (Exception $e) {
            $errors[] = "Error processing user at index $index: " . $e->getMessage();
            error_log("SYNC_ERROR: Index $index - " . $e->getMessage());
            continue;
        }
    }

    // Opsional: hapus data users yang TIDAK ada di daftar PPP saat ini (untuk router_id ini saja)
    if ($doPrune) {
        // Jika tidak ada user yang masuk, jangan hapus semua; abaikan
        if (count($incomingUsernames) > 0) {
            // Sebelum prune, buat backup untuk keamanan
            $backup_table = createUsersBackup($conn, $router_id);
            error_log("SYNC_INFO: Backup dibuat di tabel $backup_table sebelum prune.");
            
            // Hapus dalam batch agar query tidak terlalu panjang
            $batchSize = 200;
            // Buat set unik untuk menghindari duplikasi
            $incomingUsernames = array_values(array_unique($incomingUsernames));
            
            // Dapatkan daftar user_id yang akan dihapus (untuk logging)
            $placeholders = str_repeat('?,', count($incomingUsernames) - 1) . '?';
            $sql = "SELECT id, username FROM users WHERE router_id = ? AND username NOT IN ($placeholders)";
            $stmt = $conn->prepare($sql);
            if ($stmt) {
                $params = array_merge([$router_id], $incomingUsernames);
                $types = str_repeat('s', count($params));
                $stmt->bind_param($types, ...$params);
                $stmt->execute();
                $result = $stmt->get_result();
                $usersToBeDeleted = [];
                while ($row = $result->fetch_assoc()) {
                    $usersToBeDeleted[] = $row;
                }
                $stmt->close();
                
                // Log informasi penghapusan
                error_log("SYNC_INFO: Akan menghapus " . count($usersToBeDeleted) . " user untuk router_id $router_id");
                foreach ($usersToBeDeleted as $user) {
                    error_log("SYNC_INFO: Menghapus user ID {$user['id']}: {$user['username']}");
                }
            }
            
            // Siapkan placeholder untuk NOT IN
            for ($i = 0; $i < count($incomingUsernames); $i += $batchSize) {
                $batch = array_slice($incomingUsernames, $i, $batchSize);
                // Buat placeholder seperti ?,?,?,...
                $placeholders = implode(',', array_fill(0, count($batch), '?'));
                $types = str_repeat('s', count($batch) + 1); // +1 untuk router_id
                $sql = "DELETE FROM users WHERE router_id = ? AND username NOT IN ($placeholders)";
                $stmt = $conn->prepare($sql);
                if ($stmt) {
                    // Bind router_id + batch usernames
                    $params = array_merge([$router_id], $batch);
                    $stmt->bind_param($types, ...$params);
                    if ($stmt->execute()) {
                        $pruned += $stmt->affected_rows;
                    }
                    $stmt->close();
                }
            }
        }
    }

    // Return result dengan error info jika ada
    $result = [
        "success" => true, 
        "added" => $added, 
        "updated" => $updated,
        "skipped" => $skipped,
        "pruned" => $pruned,
        "total_processed" => count($data['ppp_users'])
    ];

    if (!empty($errors)) {
        $result["warnings"] = $errors;
    }

    echo json_encode($result);
    $conn->close();
    
} catch (Exception $e) {
    // Tangkap semua exception yang tidak tertangani
    error_log("SYNC_FATAL_ERROR: " . $e->getMessage() . " | File: " . $e->getFile() . " | Line: " . $e->getLine());
    returnError("Fatal error: " . $e->getMessage() . " (Line: " . $e->getLine() . ")", 500);
} catch (Error $e) {
    // Tangkap PHP 7+ Error (fatal errors)
    error_log("SYNC_FATAL_PHP_ERROR: " . $e->getMessage() . " | File: " . $e->getFile() . " | Line: " . $e->getLine());
    returnError("Fatal PHP error: " . $e->getMessage() . " (Line: " . $e->getLine() . ")", 500);
}
?>