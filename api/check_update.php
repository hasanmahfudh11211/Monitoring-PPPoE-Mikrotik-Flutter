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
 * CONFIGURATION - Update these values when you release a new version
 */
const LATEST_VERSION = '1.0.2';
const LATEST_BUILD_NUMBER = 3;
const LATEST_APK_URL = 'https://cmmnetwork.online/files/app-release.apk';
const APK_SIZE_BYTES = 0; // Will be calculated if APK exists
const MINIMUM_REQUIRED_VERSION = '1.0.0'; // Force update if user has older version

// Optional: Add release notes
const RELEASE_NOTES = [
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
        'apk_url' => LATEST_APK_URL,
        'apk_size' => getApkSize(LATEST_APK_URL),
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

