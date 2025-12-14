<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

error_reporting(0);

$response = ["success" => false, "message" => "An unknown error occurred."];

try {
    require_once __DIR__ . '/config.php';

    // Ambil data JSON dari body request
    $input = file_get_contents("php://input");
    $data = json_decode($input, true);

    if (!isset($data['router_id']) || !isset($data['logs']) || !is_array($data['logs'])) {
        throw new Exception("Invalid data format. 'router_id' and 'logs' array required.");
    }

    $router_id = trim($data['router_id']);
    $logs = $data['logs'];
    $saved_count = 0;
    $ip_address = $_SERVER['REMOTE_ADDR'];

    // Prepare statement untuk cek duplikat
    // Kita cek berdasarkan router_id, waktu log (created_at), dan isi pesan (details)
    // Asumsi: 'time' dari Mikrotik dikonversi jadi 'created_at' oleh aplikasi Flutter sebelum dikirim
    // Atau aplikasi kirim raw time string, kita simpan di details atau kolom lain?
    // Sesuai schema system_logs: username, action, details, router_id, ip_address, created_at
    
    $checkStmt = $conn->prepare("SELECT id FROM system_logs WHERE router_id = ? AND action = ? AND details = ? AND created_at = ? LIMIT 1");
    
    $insertStmt = $conn->prepare("INSERT INTO system_logs (router_id, username, action, details, ip_address, created_at) VALUES (?, ?, ?, ?, ?, ?)");

    foreach ($logs as $log) {
        // Validasi item log
        if (!isset($log['action']) || !isset($log['message']) || !isset($log['time'])) {
            continue;
        }

        $action = trim($log['action']); // e.g., 'PPPoE', 'SYSTEM', 'ACCOUNT'
        $details = trim($log['message']);
        $username = isset($log['username']) ? trim($log['username']) : 'System';
        
        // Format waktu: Aplikasi harus mengirim format 'YYYY-MM-DD HH:mm:ss'
        // Jika format dari Mikrotik cuma 'HH:mm:ss', aplikasi harus menambahkan Tanggal Hari Ini.
        $created_at = trim($log['time']); 

        // 1. Cek Duplikat
        $checkStmt->bind_param("ssss", $router_id, $action, $details, $created_at);
        $checkStmt->execute();
        $checkResult = $checkStmt->get_result();

        if ($checkResult->num_rows == 0) {
            // 2. Belum ada, Insert
            $insertStmt->bind_param("ssssss", $router_id, $username, $action, $details, $ip_address, $created_at);
            if ($insertStmt->execute()) {
                $saved_count++;
            }
        }
    }

    $checkStmt->close();
    $insertStmt->close();

    // 3. Auto-Prune (Pembersihan Otomatis)
    // Hapus log > 30 hari. Probabilitas 1% setiap request.
    if (rand(1, 100) == 1) {
        $pruneSql = "DELETE FROM system_logs WHERE created_at < NOW() - INTERVAL 30 DAY";
        $conn->query($pruneSql);
    }

    $response["success"] = true;
    $response["message"] = "Sync completed. Saved $saved_count new logs.";
    $response["saved_count"] = $saved_count;

} catch (Exception $e) {
    http_response_code(500);
    $response["message"] = $e->getMessage();
}

if (isset($conn) && $conn instanceof mysqli) { $conn->close(); }
echo json_encode($response);
?>
