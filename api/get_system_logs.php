<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

error_reporting(0);

$response = ["success" => false, "data" => [], "error" => "An unknown error occurred."];

try {
    require_once __DIR__ . '/config.php';

    $router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : '';
    if ($router_id === '') {
        throw new Exception("router_id is required");
    }

    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 50;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
    
    // Batasi limit agar tidak terlalu besar
    if ($limit > 100) $limit = 100;

    // Query Utama
    $sql = "SELECT id, created_at as timestamp, username, action, details, ip_address 
            FROM system_logs 
            WHERE router_id = ? 
            ORDER BY id DESC 
            LIMIT ? OFFSET ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("SQL prepare failed: " . $conn->error);
    }

    $stmt->bind_param("sii", $router_id, $limit, $offset);
    
    if (!$stmt->execute()) {
        throw new Exception("SQL execute failed: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $logs = [];
    while ($row = $result->fetch_assoc()) {
        $logs[] = $row;
    }

    $response["success"] = true;
    $response["data"] = $logs;
    unset($response["error"]);

} catch (Exception $e) {
    http_response_code(500);
    $response["error"] = $e->getMessage();
}

if (isset($conn) && $conn instanceof mysqli) { $conn->close(); }
echo json_encode($response);
?>
