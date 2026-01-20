<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

// Enable error reporting for debugging (bisa dimatikan di production)
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
$username = $data->username ?? '';
$router_id = $data->router_id ?? '';
$wa = $data->wa ?? '';
$maps = $data->maps ?? '';
$alamat = $data->alamat ?? '';
$redaman = $data->redaman ?? '';

// Handle tanggal_tagihan: set NULL jika kosong
$tanggal_tagihan = !empty($data->tanggal_tagihan) ? $data->tanggal_tagihan : null;

// Handle odp_id: set NULL jika kosong atau 0 atau string "null"
$odp_id = null;
if (isset($data->odp_id)) {
    if ($data->odp_id !== '' && $data->odp_id !== 'null' && $data->odp_id !== 0 && $data->odp_id !== '0') {
        $odp_id = (int)$data->odp_id;
    }
}

if (empty($router_id)) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "router_id tidak boleh kosong"]);
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

// Update data user
$sql = "UPDATE users SET 
        wa = ?,
        maps = ?,
        alamat = ?,
        redaman = ?,
        tanggal_tagihan = ?,
        odp_id = ?";

// Tipe data untuk bind_param
// s = string, i = integer
// Kita gunakan 's' untuk odp_id juga agar bisa handle NULL dengan benar di driver mysqli tertentu,
// tapi idealnya 'i' jika integer. Namun jika NULL, bind_param butuh penanganan khusus.
// Cara paling aman untuk nullable di mysqli procedural/OOP sederhana adalah dengan variable reference yang bernilai null.

$types = "sssssi"; 
// Note: odp_id (i) akan otomatis handle null jika variablenya null

$params = [
    &$wa, 
    &$maps, 
    &$alamat, 
    &$redaman, 
    &$tanggal_tagihan, 
    &$odp_id
];

// Tambahkan foto ke query update hanya jika ada foto baru
if (!empty($fotoPath)) {
    $sql .= ", foto = ?";
    $types .= "s";
    $params[] = &$fotoPath;
}

$sql .= " WHERE username = ? AND router_id = ?";
$types .= "ss";
$params[] = &$username;
$params[] = &$router_id;

try {
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Prepare failed: " . $conn->error);
    }
    
    // bind_param butuh array of references jika pakai call_user_func_array, 
    // tapi di PHP modern bisa langsung spread operator ...$params
    // Masalahnya bind_param strict dengan types.
    
    $stmt->bind_param($types, ...$params);

    if ($stmt->execute()) {
        if ($stmt->affected_rows > 0) {
            echo json_encode([
                "success" => true,
                "message" => "Data tambahan berhasil diupdate"
            ]);
        } else {
            // Tidak ada row yang berubah (mungkin data sama)
            // Kita anggap sukses saja, atau beri info
            echo json_encode([
                "success" => true, 
                "message" => "Data disimpan (tidak ada perubahan terdeteksi atau user baru)"
            ]);
        }
    } else {
        throw new Exception("Execute failed: " . $stmt->error);
    }
} catch (Exception $e) {
    logError("Error update_data_tambahan: " . $e->getMessage() . " | Data: " . json_encode($data));
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => "Gagal mengupdate data: " . $e->getMessage()
    ]);
}

$conn->close();
?>
