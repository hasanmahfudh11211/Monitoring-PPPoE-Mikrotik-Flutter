<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
error_reporting(0);

$response = ["success" => false, "users" => [], "error" => "An unknown error occurred."];

try {
    require_once __DIR__ . '/config.php';
    require_once __DIR__ . '/router_id_helper.php';
    
    $router_id = requireRouterIdFromGet($conn);
    $odp_id = isset($_GET['odp_id']) ? (int)$_GET['odp_id'] : null;
    $page = isset($_GET['page']) ? max(1, intval($_GET['page'])) : 1;
    $limit = isset($_GET['limit']) ? max(1, intval($_GET['limit'])) : 50;
    $offset = ($page - 1) * $limit;

    // Hitung total user
    $countSql = "SELECT COUNT(*) as total FROM users WHERE router_id = ?" . ($odp_id !== null ? " AND odp_id = ?" : "");
    $countStmt = $conn->prepare($countSql);
    if ($odp_id !== null) {
        $countStmt->bind_param("si", $router_id, $odp_id);
    } else {
        $countStmt->bind_param("s", $router_id);
    }
    $countStmt->execute();
    $countResult = $countStmt->get_result();
    $totalRow = $countResult->fetch_assoc();
    $total = $totalRow['total'] ?? 0;
    $countStmt->close();

    $sql = "SELECT 
                u.username, u.password, u.profile, u.wa, u.foto, u.maps,
                DATE_FORMAT(u.tanggal_dibuat, '%Y-%m-%d %H:%i:%s') as tanggal_dibuat,
                u.odp_id, o.name as odp_name
            FROM users u
            LEFT JOIN odp o ON u.odp_id = o.id
            WHERE u.router_id = ?";
    $params = [$router_id];
    $types = "s";
    if ($odp_id !== null) {
        $sql .= " AND u.odp_id = ?";
        $params[] = $odp_id;
        $types .= "i";
    }
    $sql .= " ORDER BY u.username ASC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("SQL prepare failed: " . $conn->error);
    }
    $stmt->bind_param($types, ...$params);
    if (!$stmt->execute()) {
        throw new Exception("SQL execute failed: " . $stmt->error);
    }
    $result = $stmt->get_result();
    $users = [];
    while ($row = $result->fetch_assoc()) {
        if (!empty($row['foto'])) {
            $row['foto'] = 'http://' . $_SERVER['HTTP_HOST'] . '/api/' . $row['foto'];
        }
        $users[] = $row;
    }
    $response["success"] = true;
    $response["users"] = $users;
    $response["total"] = $total;
    $response["page"] = $page;
    $response["limit"] = $limit;
    unset($response["error"]);
} catch (Exception $e) {
    http_response_code(500);
    $response["error"] = $e->getMessage();
}
$conn->close();
echo json_encode($response);
?> 