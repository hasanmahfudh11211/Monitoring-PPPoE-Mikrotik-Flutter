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

// Ambil data dari JSON
$username = $data->username ?? '';
$router_id = $data->router_id ?? '';
$wa = $data->wa ?? '';
$maps = $data->maps ?? '';
$odp_id = isset($data->odp_id) ? (int)$data->odp_id : null;

if (empty($router_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "router_id tidak boleh kosong"]);
    exit();
}

// Proses gambar base64 jika ada
$fotoPath = '';
if (!empty($data->foto)) {
    $imgData = $data->foto;
    $imgData = str_replace('data:image/jpeg;base64,', '', $imgData);
    $imgData = str_replace('data:image/png;base64,', '', $imgData);
    $imgData = str_replace(' ', '+', $imgData);
    $imgDecoded = base64_decode($imgData);

    if ($imgDecoded !== false) {
        $fileName = 'foto_' . uniqid() . '.png';
        $savePath = __DIR__ . '/uploads/' . $fileName;
        // Pastikan folder uploads sudah ada dan bisa ditulis
        if (!is_dir(__DIR__ . '/uploads')) {
            mkdir(__DIR__ . '/uploads', 0777, true);
        }
        file_put_contents($savePath, $imgDecoded);
        $fotoPath = 'uploads/' . $fileName;
    }
}

// Update data user
$sql = "UPDATE users SET 
        wa = ?,
        maps = ?,
        odp_id = ?";

$types = "ssi";
$params = [$wa, $maps, $odp_id];

// Tambahkan foto ke query update hanya jika ada foto baru
if (!empty($fotoPath)) {
    $sql .= ", foto = ?";
    $types .= "s";
    $params[] = $fotoPath;
}

$sql .= " WHERE username = ? AND router_id = ?";
$types .= "ss";
$params[] = $username;
$params[] = $router_id;

$stmt = $conn->prepare($sql);
$stmt->bind_param($types, ...$params);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo json_encode([
            "success" => true,
            "message" => "Data tambahan berhasil diupdate"
        ]);
    } else {
        http_response_code(404);
        echo json_encode([
            "success" => false,
            "error" => "User tidak ditemukan atau tidak ada perubahan data"
        ]);
    }
} else {
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $conn->error
    ]);
}

$conn->close();
?>
