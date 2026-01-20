<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
error_reporting(0); // Sembunyikan error PHP agar tidak merusak JSON

$response = ["success" => false, "users" => [], "error" => "An unknown error occurred."];

try {
    // Koneksi ke database via config terpusat
    require_once __DIR__ . '/config.php';

    // $conn disediakan oleh config.php

    $router_id = isset($_GET['router_id']) ? trim($_GET['router_id']) : '';
    if ($router_id === '') {
        throw new Exception("router_id is required");
    }

    $odp_id = isset($_GET['odp_id']) ? (int)$_GET['odp_id'] : null;

    // Query utama untuk daftar user
    $sql = "SELECT 
                u.id,
                TRIM(u.username) AS username,
                u.password,
                u.profile,
                u.wa,
                u.foto,
                u.maps,
                u.lat,
                u.lng,
                u.alamat,
                u.redaman,
                u.tanggal_tagihan,
                DATE_FORMAT(u.tanggal_dibuat, '%Y-%m-%d %H:%i:%s') as tanggal_dibuat,
                u.odp_id,
                o.name as odp_name
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

    $sql .= " ORDER BY u.username ASC";
    
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
            $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $row['foto'] = $scheme . '://' . $_SERVER['HTTP_HOST'] . '/api/' . $row['foto'];
        }
        $users[] = $row;
    } 

    // Query COUNT yang sejalan dengan filter di atas
    $countSql = "SELECT COUNT(*) AS c FROM users u WHERE u.router_id = ?";
    $countTypes = "s";
    $countParams = [$router_id];
    if ($odp_id !== null) {
        $countSql .= " AND u.odp_id = ?";
        $countTypes .= "i";
        $countParams[] = $odp_id;
    }
    $countStmt = $conn->prepare($countSql);
    if (!$countStmt) {
        throw new Exception("SQL prepare (count) failed: " . $conn->error);
    }
    $countStmt->bind_param($countTypes, ...$countParams);
    if (!$countStmt->execute()) {
        throw new Exception("SQL execute (count) failed: " . $countStmt->error);
    }
    $countRes = $countStmt->get_result()->fetch_assoc();
    $totalCount = (int)($countRes['c'] ?? 0);
    $countStmt->close();

    $response["success"] = true;
    $response["users"] = $users;
    $response["count"] = $totalCount;
    unset($response["error"]);

} catch (Exception $e) {
    http_response_code(500);
    $response["error"] = $e->getMessage();
}

if (isset($conn) && $conn instanceof mysqli) { $conn->close(); }
echo json_encode($response);
?>