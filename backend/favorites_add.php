<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Alleen POST toegestaan.']);
    exit;
}

require_once __DIR__ . '/db.php';

$input = json_decode(file_get_contents('php://input'), true) ?? [];
$userId = filter_var($input['user_id'] ?? null, FILTER_VALIDATE_INT);
$itemType = trim($input['item_type'] ?? '');
$itemId = filter_var($input['item_id'] ?? null, FILTER_VALIDATE_INT);

if (!$userId || $itemType === '' || !$itemId) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'user_id, item_type en item_id zijn verplicht.']);
    exit;
}

$userCheck = $pdo->prepare('SELECT id FROM users WHERE id = ?');
$userCheck->execute([$userId]);
if (!$userCheck->fetch()) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Onbekende gebruiker.']);
    exit;
}

$stmt = $pdo->prepare(
    'INSERT IGNORE INTO favorites (user_id, item_type, item_id) VALUES (?, ?, ?)'
);
$stmt->execute([$userId, $itemType, $itemId]);

echo json_encode(['success' => true]);
