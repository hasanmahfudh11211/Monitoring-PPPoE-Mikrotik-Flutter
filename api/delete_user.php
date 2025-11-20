<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

// Ambil data JSON dari input
$data = json_decode(file_get_contents("php://input"));

if (!$data) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "No JSON data received"]);
    exit();
}

// Ambil username dan router_id dari JSON
$username = trim($data->username ?? '');
$router_id = trim($data->router_id ?? '');

if (empty($username)) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Username tidak boleh kosong"]);
    exit();
}

if (empty($router_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "router_id tidak boleh kosong"]);
    exit();
}

// Hapus user dari database dengan filter router_id
$sql = "DELETE FROM users WHERE username = ? AND router_id = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ss", $username, $router_id);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode([
            "success" => true,
            "message" => "User berhasil dihapus"
        ]);
    } else {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "error" => "User tidak ditemukan"
        ]);
    }
} else {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $stmt->error
    ]);
}
$stmt->close();

$conn->close();
?>

