<?php
/**
 * Helper script untuk cek duplikat data di database
 * Usage: http://your-server/api/check_duplicates.php
 */

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . '/config.php';

try {
    if (!isset($conn) || $conn === null) {
        throw new Exception("Database connection failed");
    }
    
    if ($conn->connect_error) {
        throw new Exception("Database connection error: " . $conn->connect_error);
    }
    
    $results = [];
    
    // 1. Cek duplikat per router_id
    $query1 = "
        SELECT router_id, COUNT(*) as count
        FROM users
        WHERE router_id != ''
        GROUP BY router_id
        ORDER BY count DESC
    ";
    $result1 = $conn->query($query1);
    $routerCounts = [];
    while ($row = $result1->fetch_assoc()) {
        $routerCounts[] = $row;
    }
    
    // 2. Cek username yang duplikat antar router_id
    $query2 = "
        SELECT username, 
               GROUP_CONCAT(DISTINCT router_id ORDER BY router_id SEPARATOR ' || ') as router_ids,
               COUNT(*) as count
        FROM users
        WHERE username != ''
        GROUP BY username
        HAVING count > 1
        ORDER BY count DESC
    ";
    $result2 = $conn->query($query2);
    $duplicates = [];
    while ($row = $result2->fetch_assoc()) {
        $duplicates[] = $row;
    }
    
    // 3. Cek payments yang butuh update
    $query3 = "
        SELECT p.router_id as payment_router_id, u.router_id as user_router_id, COUNT(*) as count
        FROM payments p
        INNER JOIN users u ON p.user_id = u.id
        WHERE p.router_id != u.router_id
        GROUP BY p.router_id, u.router_id
    ";
    $result3 = $conn->query($query3);
    $paymentMismatches = [];
    while ($row = $result3->fetch_assoc()) {
        $paymentMismatches[] = $row;
    }
    
    $results = [
        'success' => true,
        'timestamp' => date('Y-m-d H:i:s'),
        'stats' => [
            'total_users' => $conn->query("SELECT COUNT(*) as count FROM users")->fetch_assoc()['count'],
            'total_router_ids' => count($routerCounts),
            'duplicate_usernames' => count($duplicates),
            'payment_mismatches' => count($paymentMismatches)
        ],
        'data' => [
            'router_counts' => $routerCounts,
            'duplicate_users' => $duplicates,
            'payment_mismatches' => $paymentMismatches
        ],
        'recommendations' => []
    ];
    
    // Generate recommendations
    if (count($duplicates) > 0) {
        $oldFormat = [];
        $newFormat = [];
        foreach ($routerCounts as $rc) {
            if (strpos($rc['router_id'], 'RB-') === 0 && strpos($rc['router_id'], '@') !== false) {
                $oldFormat[] = $rc['router_id'];
            } elseif (preg_match('/^[A-Z0-9-]{5,}$/', $rc['router_id'])) {
                $newFormat[] = $rc['router_id'];
            }
        }
        
        if (count($oldFormat) > 0 && count($newFormat) > 0) {
            $results['recommendations'][] = [
                'action' => 'merge_router_ids',
                'old_router_id' => $oldFormat[0],
                'new_router_id' => $newFormat[0],
                'reason' => 'Detected old format (RB-xxx@ip:port) and new format (serial-number), suggest merge'
            ];
        }
    }
    
    echo json_encode($results, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ], JSON_PRETTY_PRINT);
}

$conn->close();
?>





















