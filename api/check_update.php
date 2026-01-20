<?php
/**
 * Check Update API
 * Returns latest app version and download URL
 */

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Handle OPTIONS request for CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

/**
 * CONFIGURATION
 * Now loaded from version_config.php
 */
require_once __DIR__ . '/version_config.php';

// Construct the tracking URL
// Assuming download.php is in the same directory as this script
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' || $_SERVER['SERVER_PORT'] == 443) ? "https://" : "http://";
$domainName = $_SERVER['HTTP_HOST'];
$path = dirname($_SERVER['PHP_SELF']);
$TRACKING_URL = $protocol . $domainName . $path . '/download.php';

// Use constants from version_config.php
// LATEST_VERSION, LATEST_BUILD_NUMBER, MINIMUM_REQUIRED_VERSION are now available
const APK_SIZE_BYTES = 0; // Will be calculated if APK exists

// Optional: Add release notes
const RELEASE_NOTES = [
    [
        'version' => '1.0.6+7',
        'build' => 7,
        'date' => '2026-01-20',
        'notes' => [
            'Customer Map: Navigasi (Ambil Rute) ke lokasi pelanggan',
            'Customer Map: Pencarian & Filter Paket',
            'UI Upgrade: Tampilan Glassmorphism & Boxed Map',
            'Fix: Stabilitas & Perbaikan Bug'
        ]
    ],
    [
        'version' => '1.0.5+6',
        'build' => 6,
        'date' => '2026-01-18',
        'notes' => [
            'Sticky Header pada detail user',
            'Navigasi Cepat: Cari di Database & Cek Trafik',
            'Fix: Penyimpanan login domain'
        ]
    ],
    [
        'version' => '1.0.4+5',
        'build' => 5,
        'date' => '2025-12-19',
        'notes' => [
            'Perbaikan layout Dashboard (kartu simetris & proporsional)',
            'Penyesuaian padding footer di halaman detail',
            'Peningkatan stabilitas aplikasi'
        ]
    ],
    [
        'version' => '1.0.3+4',
        'build' => 4,
        'date' => '2025-12-15',
        'notes' => [
            'Penambahan fitur live notifications',
            'Perbaikan tombol back di layar login',
            'Peningkatan stabilitas aplikasi'
        ]
    ],
    [
        'version' => '1.0.2',
        'build' => 3,
        'date' => '2025-12-14',
        'notes' => [
            'Testing Update Flow:',
            '   • Uji coba fitur auto-install',
            '   • Perbaikan performa download',
            '   • Fix permission issue',
        ]
    ],
    [
        'version' => '1.0.1',
        'build' => 2,
        'date' => '2025-11-02',
        'notes' => [
            'New Features:',
            '   • Auto update system',
            '   • Improved billing filter',
            '   • Dashboard enhancements',
            '',
            'Bug Fixes:',
            '   • Fix duplicate Mikrotik entries',
            '   • ODP router_id validation',
            '   • Payment notification UI',
        ]
    ],
    [
        'version' => '1.0.0',
        'build' => 1,
        'date' => '2025-11-01',
        'notes' => [
            'Initial release',
            'Real-time PPPoE monitoring',
            'Payment management',
            'ODP management',
            'Export to Excel & PDF'
        ]
    ]
];

/**
 * Get current client version from request
 */
$clientVersion = $_GET['current_version'] ?? $_POST['current_version'] ?? null;
$clientBuild = intval($_GET['current_build'] ?? $_POST['current_build'] ?? 0);

/**
 * Calculate actual APK size if file exists
 */
function getApkSize($url) {
    $size = APK_SIZE_BYTES;
    
    // Try to get file size from server
    if (filter_var($url, FILTER_VALIDATE_URL)) {
        // Parse URL to local path if same domain
        $parsedUrl = parse_url($url);
        $path = $_SERVER['DOCUMENT_ROOT'] . $parsedUrl['path'];
        
        if (file_exists($path)) {
            $size = filesize($path);
        }
    }
    
    return $size;
}

/**
 * Check if update is required
 */
function isUpdateRequired($clientVersion, $clientBuild) {
    if ($clientVersion === null) {
        return false;
    }
    
    // Compare versions (simple string comparison for now)
    // You can use version_compare() for more complex logic
    if (version_compare($clientVersion, MINIMUM_REQUIRED_VERSION, '<')) {
        return true; // Force update
    }
    
    // Compare build numbers
    if ($clientBuild < LATEST_BUILD_NUMBER) {
        return false; // Optional update
    }
    
    return false;
}

/**
 * Check if update is available
 */
function isUpdateAvailable($clientVersion, $clientBuild) {
    if ($clientVersion === null) {
        return true; // First time check
    }
    
    // Compare build numbers
    return $clientBuild < LATEST_BUILD_NUMBER;
}

/**
 * Main response
 */
try {
    $updateRequired = isUpdateRequired($clientVersion, $clientBuild);
    $updateAvailable = isUpdateAvailable($clientVersion, $clientBuild);
    
    $response = [
        'success' => true,
        'update_available' => $updateAvailable,
        'update_required' => $updateRequired,
        'latest_version' => LATEST_VERSION,
        'latest_build' => LATEST_BUILD_NUMBER,
        'apk_url' => $TRACKING_URL, // Points to download.php
        'apk_size' => getApkSize(REAL_APK_URL), // Check size of actual file
        'minimum_required_version' => MINIMUM_REQUIRED_VERSION,
        'release_notes' => RELEASE_NOTES,
        'timestamp' => date('Y-m-d H:i:s')
    ];
    
    http_response_code(200);
    echo json_encode($response, JSON_PRETTY_PRINT);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Internal server error: ' . $e->getMessage()
    ]);
}

