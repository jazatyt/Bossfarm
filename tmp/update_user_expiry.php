<?php
header("Content-Type: application/json");
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit();
}

require_once 'db_connect.php'; // adjust path if needed

$data = json_decode(file_get_contents("php://input"), true);

if (!isset($data['username']) || !isset($data['days'])) {
    echo json_encode(['status' => 'error', 'message' => 'Missing username or days']);
    exit();
}

$username = trim($data['username']);
$days     = intval($data['days']);

if ($days <= 0 || $days > 3650) {
    echo json_encode(['status' => 'error', 'message' => 'Invalid days value (1–3650)']);
    exit();
}

try {
    // Fetch current expiry_date for this user
    $stmt = $pdo->prepare("SELECT expiry_date FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$row) {
        echo json_encode(['status' => 'error', 'message' => 'User not found']);
        exit();
    }

    $currentExpiry = $row['expiry_date'];

    // If expiry_date exists and is in the future, extend from that date.
    // Otherwise (null or already expired), set from today.
    if ($currentExpiry !== null) {
        $base = new DateTime($currentExpiry);
        $now  = new DateTime();
        if ($base < $now) {
            $base = $now; // expired → reset to today
        }
    } else {
        $base = new DateTime(); // no expiry → start from today
    }

    $base->modify("+{$days} days");
    $newExpiry = $base->format('Y-m-d H:i:s');

    $update = $pdo->prepare("UPDATE users SET expiry_date = ? WHERE username = ?");
    $update->execute([$newExpiry, $username]);

    echo json_encode([
        'status'     => 'success',
        'message'    => "Extended by {$days} days",
        'new_expiry' => $newExpiry,
    ]);
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
