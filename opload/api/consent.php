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
$termsVersion = trim($input['terms_version'] ?? '');
$privacyVersion = trim($input['privacy_version'] ?? '');
$requiredFlags = [
    'age_confirmed',
    'lawful_alcohol_use',
    'accurate_account_data',
    'personal_account',
    'credentials_secure',
    'no_impersonation',
];

if (!$userId || $termsVersion === '' || $privacyVersion === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Account en versies van de voorwaarden zijn verplicht.']);
    exit;
}

foreach ($requiredFlags as $flag) {
    if (empty($input[$flag])) {
        http_response_code(400);
        echo json_encode(['success' => false, 'error' => 'Alle account- en veiligheidsbevestigingen zijn verplicht.']);
        exit;
    }
}

$userCheck = $pdo->prepare('SELECT id FROM users WHERE id = ?');
$userCheck->execute([$userId]);
if (!$userCheck->fetch()) {
    http_response_code(404);
    echo json_encode(['success' => false, 'error' => 'Account niet gevonden.']);
    exit;
}

$statement = $pdo->prepare(
    'INSERT INTO user_consents (
        user_id, terms_version, privacy_version, accepted_at, age_confirmed,
        lawful_alcohol_use, accurate_account_data, personal_account,
        credentials_secure, no_impersonation
    ) VALUES (?, ?, ?, CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE accepted_at = CURRENT_TIMESTAMP'
);
$statement->execute([
    $userId,
    $termsVersion,
    $privacyVersion,
    1,
    1,
    1,
    1,
    1,
    1,
]);

echo json_encode(['success' => true]);