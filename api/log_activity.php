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
    $data = json_decode(file_get_contents("php://input"), true);

    if (!isset($data['username']) || !isset($data['action']) || !isset($data['router_id'])) {
        throw new Exception("Parameter tidak lengkap (username, action, router_id wajib ada)");
    }

    $username = trim($data['username']);
    $action = trim($data['action']);
    $details = isset($data['details']) ? trim($data['details']) : '';
    $router_id = trim($data['router_id']);
    $ip_address = $_SERVER['REMOTE_ADDR'];

    // 1. Insert Log Baru
    $sql = "INSERT INTO system_logs (username, action, details, router_id, ip_address) VALUES (?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("SQL prepare failed: " . $conn->error);
    }
    $stmt->bind_param("sssss", $username, $action, $details, $router_id, $ip_address);
    
    if ($stmt->execute()) {
        $response["success"] = true;
        $response["message"] = "Log berhasil disimpan";
    } else {
        throw new Exception("Gagal menyimpan log: " . $stmt->error);
    }
    $stmt->close();

    // 2. Auto-Prune (Pembersihan Otomatis)
    // Jalankan hanya dengan probabilitas 1% (1 dari 100 request) agar tidak memberatkan server
    if (rand(1, 100) == 1) {
        // Hapus log yang lebih tua dari 30 hari
        $pruneSql = "DELETE FROM system_logs WHERE created_at < NOW() - INTERVAL 30 DAY";
        $conn->query($pruneSql);
    }

} catch (Exception $e) {
    http_response_code(500);
    $response["message"] = $e->getMessage();
}

if (isset($conn) && $conn instanceof mysqli) { $conn->close(); }
echo json_encode($response);
?>
