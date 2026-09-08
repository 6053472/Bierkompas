<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Alleen GET toegestaan.']);
    exit;
}

require_once __DIR__ . '/db.php';

$userId = filter_input(INPUT_GET, 'user_id', FILTER_VALIDATE_INT);
if (!$userId) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'user_id is verplicht.']);
    exit;
}

$stmt = $pdo->prepare(
    'SELECT id, item_type, item_id, created_at FROM favorites WHERE user_id = ? ORDER BY created_at DESC'
);
$stmt->execute([$userId]);

echo json_encode(['success' => true, 'favorites' => $stmt->fetchAll()]);
