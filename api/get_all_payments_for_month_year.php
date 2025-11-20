<?php
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/router_id_helper.php';

$router_id = requireRouterIdFromGet($conn);
$month = isset($_GET['month']) ? intval($_GET['month']) : 0;
$year = isset($_GET['year']) ? intval($_GET['year']) : 0;
if ($month <= 0 || $year <= 0) {
    http_response_code(400);
    echo json_encode(["success" => false, "error" => "Parameter bulan/tahun tidak valid"]);
    exit();
}

$sql = "SELECT * FROM payments WHERE router_id = ? AND payment_month = ? AND payment_year = ? ORDER BY payment_date DESC";
$stmt = $conn->prepare($sql);
$stmt->bind_param("sii", $router_id, $month, $year);
$stmt->execute();
$result = $stmt->get_result();

$data = [];
while ($row = $result->fetch_assoc()) {
    $data[] = $row;
}

$stmt->close();
$conn->close();
echo json_encode(["success" => true, "data" => $data]);
exit(); 