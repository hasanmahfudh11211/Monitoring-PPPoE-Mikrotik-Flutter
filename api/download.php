<?php
/**
 * Download Handler
 * Logs the download attempt and redirects to the actual APK file
 */

require_once __DIR__ . '/config.php';
require_once __DIR__ . '/version_config.php';

// Get visitor info
$ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? 'unknown';
$version = LATEST_VERSION;

// Log to database
if (isset($conn)) {
    try {
        $stmt = $conn->prepare("INSERT INTO download_logs (ip_address, user_agent, version, status) VALUES (?, ?, ?, 'success')");
        if ($stmt) {
            $stmt->bind_param("sss", $ip_address, $user_agent, $version);
            $stmt->execute();
            $stmt->close();
        }
    } catch (Exception $e) {
        // Silently fail logging so download still works
        error_log("Download logging failed: " . $e->getMessage());
    }
}

// Redirect to the actual file
header("Location: " . REAL_APK_URL);
exit;
?>
