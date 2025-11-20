<?php
header("Content-Type: application/json; charset=UTF-8");

require_once __DIR__ . '/config.php';

$pppoe_user = isset($_GET['user']) ? $_GET['user'] : '';
if (empty($pppoe_user)) {
    die(json_encode(["error" => "Parameter 'user' wajib diisi."]));
}

// Mengambil data dari tabel 'detail_pelanggan'
$stmt = $conn->prepare("SELECT pppoe_user, nomor_hp, link_gmaps, foto_path FROM detail_pelanggan WHERE pppoe_user = ?");
$stmt->bind_param("s", $pppoe_user);
$stmt->execute();
$result = $stmt->get_result();
$data = $result->fetch_assoc();

echo json_encode($data ? $data : ["message" => "Data tidak ditemukan."]);

$stmt->close();
$conn->close();
?>
