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
require_once __DIR__ . '/router_id_helper.php';

$router_id = requireRouterIdFromGet($conn);

// Query summary pembayaran per bulan/tahun untuk router tertentu
$sql = "SELECT payment_month, payment_year, SUM(amount) as total, COUNT(*) as count FROM payments WHERE router_id = ? GROUP BY payment_year, payment_month ORDER BY payment_year DESC, payment_month DESC";
$stmt = $conn->prepare($sql);
$stmt->bind_param("s", $router_id);
$stmt->execute();
$result = $stmt->get_result();

$summary = [];
while ($row = $result->fetch_assoc()) {
    $summary[] = [
        'month' => intval($row['payment_month']),
        'year' => intval($row['payment_year']),
        'total' => floatval($row['total']),
        'count' => intval($row['count'])
    ];
}

echo json_encode(["success" => true, "data" => $summary]);
$stmt->close();
$conn->close();
exit(); 