<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

// Enable error reporting for debugging
ini_set('display_errors', 0);
ini_set('log_errors', 1);
$logFile = __DIR__ . '/debug_log.txt';
ini_set('error_log', $logFile);

function logError($message) {
    global $logFile;
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $message" . PHP_EOL, FILE_APPEND);
}

// Ambil data JSON dari input
$input = file_get_contents("php://input");
$data = json_decode($input);

if (!$data) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "No JSON data received"]);
    exit();
}

// Ambil data dari JSON
$router_id = $data->router_id ?? '';
$username = $data->username ?? '';
$password = $data->password ?? '';
$profile  = $data->profile ?? '';
$wa       = $data->wa ?? '';
$maps     = $data->maps ?? '';
$alamat   = $data->alamat ?? '';
$redaman  = $data->redaman ?? '';

// Handle tanggal_tagihan: set NULL jika kosong
$tanggal_tagihan = !empty($data->tanggal_tagihan) ? $data->tanggal_tagihan : null;

$tanggal  = $data->tanggal_dibuat ?? '';

if ($router_id === '') {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "router_id required"]);
    exit();
}

// Proses gambar base64 jika ada
$fotoPath = '';
if (!empty($data->foto)) {
    $imgData = $data->foto;
    // Cek apakah ini URL (artinya tidak ada perubahan foto) atau base64
    if (strpos($imgData, 'http') === 0) {
        // Ini URL, abaikan (tidak update foto)
        $fotoPath = ''; 
    } else {
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
            if (file_put_contents($savePath, $imgDecoded)) {
                $fotoPath = 'uploads/' . $fileName;
            } else {
                logError("Gagal menyimpan file foto ke $savePath");
            }
        } else {
            logError("Gagal decode base64 image");
        }
    }
}

try {
    // Cek apakah user sudah ada dalam router yang sama
    $checkStmt = $conn->prepare("SELECT id FROM users WHERE username = ? AND router_id = ?");
    if (!$checkStmt) throw new Exception("Prepare check failed: " . $conn->error);
    
    $checkStmt->bind_param("ss", $username, $router_id);
    $checkStmt->execute();
    $result = $checkStmt->get_result();
    $exists = $result->num_rows > 0;
    $checkStmt->close();

    if ($exists) {
        // Update user yang sudah ada
        if (!empty($fotoPath)) {
            $sql = "UPDATE users SET password = ?, profile = ?, wa = ?, maps = ?, alamat = ?, redaman = ?, tanggal_tagihan = ?, tanggal_dibuat = ?, foto = ? WHERE username = ? AND router_id = ?";
            $types = "sssssssssss";
            $params = [
                &$password, &$profile, &$wa, &$maps, &$alamat, &$redaman, &$tanggal_tagihan, &$tanggal, &$fotoPath, &$username, &$router_id
            ];
        } else {
            $sql = "UPDATE users SET password = ?, profile = ?, wa = ?, maps = ?, alamat = ?, redaman = ?, tanggal_tagihan = ?, tanggal_dibuat = ? WHERE username = ? AND router_id = ?";
            $types = "ssssssssss";
            $params = [
                &$password, &$profile, &$wa, &$maps, &$alamat, &$redaman, &$tanggal_tagihan, &$tanggal, &$username, &$router_id
            ];
        }
    } else {
        // Insert user baru
        $sql = "INSERT INTO users (router_id, username, password, profile, wa, foto, maps, alamat, redaman, tanggal_tagihan, tanggal_dibuat) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
        $types = "sssssssssss";
        $params = [
            &$router_id, &$username, &$password, &$profile, &$wa, &$fotoPath, &$maps, &$alamat, &$redaman, &$tanggal_tagihan, &$tanggal
        ];
    }

    $stmt = $conn->prepare($sql);
    if (!$stmt) throw new Exception("Prepare failed: " . $conn->error);
    
    $stmt->bind_param($types, ...$params);

    if ($stmt->execute()) {
        echo json_encode([
            "success" => true,
            "message" => $exists ? "User updated successfully" : "User added successfully"
        ]);
    } else {
        throw new Exception("Execute failed: " . $stmt->error);
    }
    $stmt->close();

} catch (Exception $e) {
    logError("Error save_user: " . $e->getMessage() . " | Data: " . json_encode($data));
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => "Gagal menyimpan user: " . $e->getMessage()
    ]);
}

$conn->close();
?>
