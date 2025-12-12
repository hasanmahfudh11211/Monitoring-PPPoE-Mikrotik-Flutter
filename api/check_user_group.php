<?php
// Matikan display errors agar tidak merusak JSON
ini_set('display_errors', 0);
error_reporting(E_ALL);

header('Content-Type: application/json');

// Handler untuk fatal error (misal require gagal)
register_shutdown_function(function() {
    $error = error_get_last();
    if ($error && ($error['type'] === E_ERROR || $error['type'] === E_PARSE || $error['type'] === E_COMPILE_ERROR)) {
        echo json_encode([
            'status' => false,
            'error' => 'Fatal Error: ' . $error['message'] . ' in ' . $error['file'] . ':' . $error['line']
        ]);
    }
});

try {
    if (!file_exists(__DIR__ . '/routerosAPI.php')) {
        throw new Exception('File routerosAPI.php tidak ditemukan');
    }
    
    require_once __DIR__ . '/routerosAPI.php';

    // Ambil input JSON
    $input = json_decode(file_get_contents('php://input'), true);

    $ip = $input['ip'] ?? '';
    $port = $input['port'] ?? 8728;
    $username = $input['username'] ?? '';
    $password = $input['password'] ?? '';
    // target_user removed

    if (!$ip || !$username || !$password) {
        throw new Exception('IP, Username, dan Password wajib diisi');
    }

    $api = new RouterosAPI();
    $api->port = $port;

    if ($api->connect($ip, $username, $password)) {
        // ... (connection successful logic) ...
        // Filter di API level (jika didukung)
        $params = ['?name' => $username];
        $users = $api->comm('/user/print', $params);
        $api->disconnect();

        // Filter di PHP level (Strict)
        $final_data = [];
        foreach ($users as $user) {
            if (isset($user['name']) && $user['name'] === $username) {
                $final_data[] = $user;
                break; // Ambil satu saja
            }
        }

        echo json_encode([
            'status' => true,
            'data' => $final_data
        ]);
        exit; // Stop execution after success
    } else {
        throw new Exception('Gagal koneksi ke MikroTik (Cek IP, Port, User, Pass)');
    }

} catch (Exception $e) {
    echo json_encode([
        'status' => false,
        'error' => $e->getMessage()
    ]);
}
