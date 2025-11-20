<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type");

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Koneksi ke database via config terpusat
require_once __DIR__ . '/config.php';

$user_id = isset($_GET['user_id']) ? intval($_GET['user_id']) : 0;
$router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : '';
if ($user_id <= 0 || $router_id === '') {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Parameter tidak valid (user_id/router_id)"]);
    exit();
}

// Query data dari tabel payments
$sql = "SELECT id, payment_month, payment_year, amount, payment_date, method, note, created_by FROM payments WHERE user_id = ? AND router_id = ? ORDER BY payment_date DESC";
$stmt = $conn->prepare($sql);
$stmt->bind_param("is", $user_id, $router_id);
$stmt->execute();
$result = $stmt->get_result();

$data = [];
while ($row = $result->fetch_assoc()) {
    $data[] = [
        'id' => $row['id'],
        'period' => $row['payment_month'] . '-' . $row['payment_year'],
        'amount' => floatval($row['amount']),
        'dueDate' => $row['payment_date'],
        'status' => $row['method'],
        'paidAt' => $row['payment_date'],
        'note' => $row['note'],
        'createdBy' => $row['created_by'],
    ];
}

echo json_encode(["status" => "success", "data" => $data]);
$stmt->close();
$conn->close();
exit();
?> 