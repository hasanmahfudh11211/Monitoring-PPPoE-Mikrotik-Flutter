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

$operation = isset($_GET['operation']) ? $_GET['operation'] : '';
$router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : '';

// =====================
// EXPORT CSV
// =====================
if ($operation === 'export') {
    if ($router_id === '') { http_response_code(400); echo 'router_id required'; exit; }
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment;filename=payments.csv');
    $output = fopen('php://output', 'w');
    fputcsv($output, ['ID', 'User', 'Amount', 'Date', 'Month', 'Year', 'Method', 'Note', 'Created By']);
    $stmt = $conn->prepare("SELECT p.id, u.username, p.amount, p.payment_date, p.payment_month, p.payment_year, p.method, p.note, p.created_by FROM payments p LEFT JOIN users u ON p.user_id = u.id WHERE p.router_id = ? ORDER BY p.payment_date DESC");
    $stmt->bind_param("s", $router_id);
    $stmt->execute();
    $result = $stmt->get_result();
    while ($row = $result->fetch_assoc()) {
        fputcsv($output, [
            $row['id'], $row['username'], $row['amount'], $row['payment_date'], $row['payment_month'], $row['payment_year'], $row['method'], $row['note'], $row['created_by']
        ]);
    }
    fclose($output);
    $stmt->close();
    exit;
}

// =====================
// CREATE (ADD PAYMENT)
// =====================
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $operation === 'add') {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!$data) {
        http_response_code(400);
        echo json_encode(["success" => false, "error" => "No JSON data received"]);
        exit();
    }
    $router_id_body = trim($data['router_id'] ?? '');
    if ($router_id_body === '') { http_response_code(400); echo json_encode(["success"=>false, "error"=>"router_id required"]); exit(); }
    $user_id = (int)($data['user_id'] ?? 0);
    $amount = (float)($data['amount'] ?? 0);
    $payment_date = trim($data['payment_date'] ?? '');
    $method = trim($data['method'] ?? '');
    $note = trim($data['note'] ?? '');
    $created_by = trim($data['created_by'] ?? '');
    $date = date_create($payment_date);
    $payment_month = (int)date_format($date, "n");
    $payment_year = (int)date_format($date, "Y");
    $sql = "INSERT INTO payments (router_id, user_id, amount, payment_date, payment_month, payment_year, method, note, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $conn->error]);
        exit();
    }
    $stmt->bind_param("sidsiisss", $router_id_body, $user_id, $amount, $payment_date, $payment_month, $payment_year, $method, $note, $created_by);
    if ($stmt->execute()) {
        echo json_encode(["success" => true, "id" => $conn->insert_id]);
    } else {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $stmt->error]);
    }
    $stmt->close();
    exit();
}

// =====================
// UPDATE PAYMENT
// =====================
if ($_SERVER['REQUEST_METHOD'] === 'PUT' && $operation === 'update') {
    $data = json_decode(file_get_contents('php://input'), true);
    $debug = [];
    $debug['data'] = $data;
    if (!$data || !isset($data['id'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "error" => "No JSON data or missing ID", "debug" => $debug]);
        exit();
    }
    $id = (int)$data['id'];
    $user_id = (int)($data['user_id'] ?? 0);
    $amount = (float)($data['amount'] ?? 0);
    $payment_date = trim($data['payment_date'] ?? '');
    $method = trim($data['method'] ?? '');
    $note = trim($data['note'] ?? '');
    $created_by = trim($data['created_by'] ?? '');
    $date = date_create($payment_date);
    $payment_month = (int)date_format($date, "n");
    $payment_year = (int)date_format($date, "Y");
    $router_id_body = trim($data['router_id'] ?? '');
    if ($router_id_body === '') { http_response_code(400); echo json_encode(["success"=>false, "error"=>"router_id required"]); exit(); }
    $debug['bind'] = [
        'user_id' => $user_id,
        'amount' => $amount,
        'payment_date' => $payment_date,
        'payment_month' => $payment_month,
        'payment_year' => $payment_year,
        'method' => $method,
        'note' => $note,
        'created_by' => $created_by,
        'id' => $id
    ];
    $sql = "UPDATE payments SET user_id=?, amount=?, payment_date=?, payment_month=?, payment_year=?, method=?, note=?, created_by=? WHERE id=? AND router_id=?";
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $conn->error, "debug" => $debug]);
        exit();
    }
    $stmt->bind_param("idsiisssis", $user_id, $amount, $payment_date, $payment_month, $payment_year, $method, $note, $created_by, $id, $router_id_body);
    if ($stmt->execute()) {
        echo json_encode(["success" => true, "debug" => $debug]);
    } else {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $stmt->error, "debug" => $debug]);
    }
    $stmt->close();
    exit();
}

// =====================
// DELETE PAYMENT
// =====================
if ($_SERVER['REQUEST_METHOD'] === 'DELETE' && $operation === 'delete') {
    $data = json_decode(file_get_contents('php://input'), true);
    if (!$data || !isset($data['id'])) {
        http_response_code(400);
        echo json_encode(["success" => false, "error" => "No JSON data or missing ID"]);
        exit();
    }
    $id = (int)$data['id'];
    $router_id_body = trim($data['router_id'] ?? '');
    if ($router_id_body === '') { http_response_code(400); echo json_encode(["success"=>false, "error"=>"router_id required"]); exit(); }
    $sql = "DELETE FROM payments WHERE id=? AND router_id=?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("is", $id, $router_id_body);
    if ($stmt->execute()) {
        echo json_encode(["success" => true]);
    } else {
        http_response_code(500);
        echo json_encode(["success" => false, "error" => $stmt->error]);
    }
    $stmt->close();
    exit();
}

// =====================
// GET (LIST/FILTER)
// =====================
// GET /api/payment_operations.php?user_id=1&month=5&year=2024&router_id=SERIAL
$where = [];
$params = [];
$types = "";
if (isset($_GET['router_id']) && $_GET['router_id'] !== '') {
    $where[] = "p.router_id = ?";
    $params[] = $_GET['router_id'];
    $types .= "s";
}
if (isset($_GET['user_id'])) {
    $where[] = "p.user_id = ?";
    $params[] = $_GET['user_id'];
    $types .= "i";
}
if (isset($_GET['month'])) {
    $where[] = "p.payment_month = ?";
    $params[] = $_GET['month'];
    $types .= "i";
}
if (isset($_GET['year'])) {
    $where[] = "p.payment_year = ?";
    $params[] = $_GET['year'];
    $types .= "i";
}
$sql = "SELECT p.*, u.username FROM payments p LEFT JOIN users u ON p.user_id = u.id";
if ($where) $sql .= " WHERE " . implode(" AND ", $where);
$sql .= " ORDER BY p.payment_date DESC";
$stmt = $conn->prepare($sql);
if ($params) $stmt->bind_param($types, ...$params);
$stmt->execute();
$result = $stmt->get_result();
$data = [];
while ($row = $result->fetch_assoc()) $data[] = $row;
echo json_encode(["success" => true, "data" => $data]);
$stmt->close();
$conn->close();
exit();
?> 