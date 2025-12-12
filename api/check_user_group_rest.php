<?php
header('Content-Type: application/json');

// Ambil input JSON
$input = json_decode(file_get_contents('php://input'), true);

$ip = $input['ip'] ?? '';
$port = $input['port'] ?? 80; // Default REST port usually 80 or 443
$username = $input['username'] ?? '';
$password = $input['password'] ?? '';
// target_user removed

if (!$ip || !$username || !$password) {
    echo json_encode(['status' => false, 'error' => 'IP, Username, dan Password wajib diisi']);
    exit;
}

// Tentukan protokol (http/https) berdasarkan port
$scheme = ($port == 443) ? 'https' : 'http';
$url = "$scheme://$ip:$port/rest/user?name=" . urlencode($username);

$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, $url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_USERPWD, "$username:$password");
curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
// Fix for SSL Handshake Failure (OpenSSL 3+ vs MikroTik)
// SECLEVEL=0 allows even weaker ciphers/keys if needed
curl_setopt($ch, CURLOPT_SSL_CIPHER_LIST, 'DEFAULT@SECLEVEL=0');
// CURL_SSLVERSION_TLSv1 allows TLS 1.0, 1.1, or 1.2 (auto-negotiate from 1.0 up)
curl_setopt($ch, CURLOPT_SSLVERSION, CURL_SSLVERSION_TLSv1);

$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$error = curl_error($ch);
curl_close($ch);

if ($error) {
    $hint = '';
    if (strpos($error, 'Empty reply from server') !== false) {
        $hint = ' (Kemungkinan salah Port atau Protocol. Coba ganti Port 80/443 atau http/https)';
    } elseif (strpos($error, 'handshake failure') !== false) {
        $hint = ' (Gagal Handshake SSL. Cek kompatibilitas TLS/Cipher di MikroTik)';
    }
    echo json_encode([
        'status' => false,
        'error' => 'Curl Error: ' . $error . $hint
    ]);
    exit;
}

if ($http_code >= 200 && $http_code < 300) {
    $data = json_decode($response, true);
    
    // Filter di PHP level (Strict)
    $final_data = [];
    if (is_array($data)) {
        foreach ($data as $user) {
            if (isset($user['name']) && $user['name'] === $username) {
                $final_data[] = $user;
                break;
            }
        }
    }

    echo json_encode([
        'status' => true,
        'data' => $final_data
    ]);
} else {
    echo json_encode([
        'status' => false,
        'error' => "HTTP Error $http_code",
        'response' => $response
    ]);
}
