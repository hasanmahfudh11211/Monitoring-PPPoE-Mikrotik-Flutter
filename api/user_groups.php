<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json');
require_once __DIR__ . '/routerosAPI.php';

$api = new RouterosAPI();

// =============================
// KONFIGURASI LOGIN (INI SAJA YANG DIGANTI)
// =============================
$ip   = '10.9.8.1';
$user = 'danil';     // ganti: adam / husen / flutter
$pass = 'danil008';

$api->port = 2711;

// =============================
// CONNECT KE MIKROTIK
// =============================
if (!$api->connect($ip, $user, $pass)) {
    echo json_encode([
        'status' => false,
        'error' => 'Gagal konek ke MikroTik'
    ]);
    exit;
}

// =============================
// AMBIL DATA USER YANG DIPAKAI LOGIN
// =============================
$result = $api->comm('/user/print', [
    '?name' => $user
]);

$api->disconnect();

// =============================
// VALIDASI HASIL
// =============================
$loginUser = $result[0] ?? null;

if (!$loginUser) {
    echo json_encode([
        'status' => false,
        'error' => 'User login tidak ditemukan di MikroTik'
    ], JSON_PRETTY_PRINT);
    exit;
}


// =============================
// OUTPUT FINAL
// =============================
echo json_encode([
    'status' => true,
    'login_user' => [
        'name'     => $loginUser['name'] ?? '',
        'group'    => $loginUser['group'] ?? '',
        'disabled' => $loginUser['disabled'] ?? '',
        'expired'  => $loginUser['expired'] ?? ''
    ]
], JSON_PRETTY_PRINT);
