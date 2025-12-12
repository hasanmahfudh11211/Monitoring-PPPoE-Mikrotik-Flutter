<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);
header('Content-Type: text/plain');

$ip = '10.9.8.1';
$port = 2711;
$timeout = 5;

echo "Starting connection test to $ip:$port...\n";
flush();

$start = microtime(true);

$socket = @fsockopen($ip, $port, $errno, $errstr, $timeout);

if (!$socket) {
    echo "ERROR: fsockopen failed: $errstr ($errno)\n";
    exit;
}

echo "Socket connected! (Time: " . (microtime(true) - $start) . "s)\n";
stream_set_timeout($socket, $timeout);
flush();

// Send /login
echo "Sending /login...\n";
$command = '/login';
$len = strlen($command);
fwrite($socket, chr($len) . $command);
fwrite($socket, chr(0)); // End of command
echo "Sent /login. Waiting for response...\n";
flush();

// Read response
$byte = fread($socket, 1);
if ($byte === false || $byte === '') {
    echo "ERROR: Read failed or empty response immediately.\n";
} else {
    $len = ord($byte);
    echo "Received first byte length: $len\n";
    // Read rest...
    // Just dump whatever we get for a bit
    $rest = fread($socket, 1024);
    echo "Received data: " . bin2hex($byte . $rest) . "\n";
}

fclose($socket);
echo "Done.\n";
