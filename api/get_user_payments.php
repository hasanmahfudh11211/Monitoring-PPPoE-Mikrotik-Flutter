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

    // Ambil user_id dan router_id dari parameter
    $user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
    $router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : '';
    
    if ($user_id <= 0 || $router_id === '') {
        throw new Exception("Parameter user_id tidak valid");
    }
    
    // Ambil riwayat pembayaran user
    $sql = "SELECT id, amount, payment_date, payment_month, payment_year, method, note, created_by 
            FROM payments 
            WHERE user_id = ? AND router_id = ? 
            ORDER BY payment_date DESC";
    
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        throw new Exception("Database error: " . $conn->error);
    }
    
    $stmt->bind_param("is", $user_id, $router_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $payments = [];
    while ($row = $result->fetch_assoc()) {
        $payments[] = $row;
    }
    
    $stmt->close();
    $conn->close();
    
    echo json_encode(["success" => true, "data" => $payments]);
} catch (Exception $e) {
    // Tangani error dan kembalikan respons JSON yang valid
    http_response_code(500);
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}
exit();
?>