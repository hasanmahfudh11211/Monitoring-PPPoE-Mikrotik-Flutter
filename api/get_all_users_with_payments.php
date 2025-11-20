<?php
ini_set('display_errors', 0);
ini_set('display_startup_errors', 0);
error_reporting(0);

// Set timeout limit to prevent long-running queries
set_time_limit(30);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Koneksi ke database via config terpusat
    require_once __DIR__ . '/config.php';

    // Ambil router_id
    $router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : '';
    if ($router_id === '') {
        throw new Exception('router_id is required');
    }

    // Ambil semua user untuk router ini
    $stmt_users = $conn->prepare("SELECT * FROM users WHERE router_id = ? ORDER BY username ASC");
    $stmt_users->bind_param("s", $router_id);
    $stmt_users->execute();
    $result_users = $stmt_users->get_result();
    
    if (!$result_users) {
        throw new Exception("Database error: " . $conn->error);
    }

    $users = [];
    while ($user = $result_users->fetch_assoc()) {
        try {
            // Ambil riwayat pembayaran user ini
            $sql_payments = "SELECT id, amount, payment_date, payment_month, payment_year, method, note, created_by FROM payments WHERE user_id = ? AND router_id = ? ORDER BY payment_date DESC";
            $stmt = $conn->prepare($sql_payments);
            
            if (!$stmt) {
                // Jika prepare statement gagal, lanjutkan dengan payments kosong
                $user['payments'] = [];
                $users[] = $user;
                continue;
            }
            
            $stmt->bind_param("is", $user['id'], $router_id);
            $stmt->execute();
            $result_payments = $stmt->get_result();
            $payments = [];
            
            while ($row = $result_payments->fetch_assoc()) {
                $payments[] = $row;
            }
            
            $user['payments'] = $payments;
            $users[] = $user;
            $stmt->close();
        } catch (Exception $e) {
            // Jika ada error saat mengambil payments, tetap tambahkan user dengan payments kosong
            $user['payments'] = [];
            $users[] = $user;
        }
    }

    $stmt_users->close();
    $conn->close();
    echo json_encode(["status" => "success", "data" => $users]);
} catch (Exception $e) {
    // Tangani error dan kembalikan respons JSON yang valid
    http_response_code(500);
    echo json_encode([
        "status" => "error",
        "message" => "Terjadi kesalahan saat memproses data",
        "error" => $e->getMessage()
    ]);
}
exit();
?>