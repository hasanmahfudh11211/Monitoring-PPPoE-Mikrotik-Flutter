<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';
require_once __DIR__ . '/router_id_helper.php';

// Ambil data JSON dari input (array of users)
$data = json_decode(file_get_contents("php://input"));

if (!$data || !is_array($data)) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Invalid data format"]);
    exit();
}

// Validasi router_id dari body (harus ada di setiap user atau sebagai parameter terpisah)
// Cek dari GET parameter dulu, jika tidak ada cek dari user pertama
$router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : (isset($data[0]->router_id) ? trim($data[0]->router_id) : '');
if ($router_id === '') {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "router_id required (dapat dari GET parameter atau body)"]);
    exit();
}

$successCount = 0;
$failedCount = 0;
$failedUsers = [];

foreach ($data as $user) {
    $username = trim($user->username ?? '');
    $password = trim($user->password ?? '');
    $profile = trim($user->profile ?? '');
    $tanggal = date('Y-m-d H:i:s');

    // Cek apakah user sudah ada di router yang sama
    $checkStmt = $conn->prepare("SELECT id FROM users WHERE username = ? AND router_id = ?");
    $checkStmt->bind_param("ss", $username, $router_id);
    $checkStmt->execute();
    $result = $checkStmt->get_result();

    if ($result->num_rows > 0) {
        // Update user yang sudah ada
        $updateStmt = $conn->prepare("UPDATE users SET password = ?, profile = ?, tanggal_dibuat = ? WHERE username = ? AND router_id = ?");
        $updateStmt->bind_param("sssss", $password, $profile, $tanggal, $username, $router_id);
        if ($updateStmt->execute()) {
            $successCount++;
        } else {
            $failedCount++;
            $failedUsers[] = ['username' => $username, 'error' => $updateStmt->error];
        }
        $updateStmt->close();
    } else {
        // Insert user baru
        $insertStmt = $conn->prepare("INSERT INTO users (router_id, username, password, profile, tanggal_dibuat) VALUES (?, ?, ?, ?, ?)");
        $insertStmt->bind_param("sssss", $router_id, $username, $password, $profile, $tanggal);
        if ($insertStmt->execute()) {
            $successCount++;
        } else {
            $failedCount++;
            $failedUsers[] = ['username' => $username, 'error' => $insertStmt->error];
        }
        $insertStmt->close();
    }
    $checkStmt->close();
}

echo json_encode([
    "success" => true,
    "total" => count($data),
    "success_count" => $successCount,
    "failed_count" => $failedCount,
    "failed_users" => $failedUsers
]);

$conn->close();
?>