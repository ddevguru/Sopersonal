<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'config/db.php';

function verifyToken($token, $conn) {
    $stmt = $conn->prepare("SELECT id FROM users WHERE session_token = ? AND status = 'online'");
    $stmt->execute([$token]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    return $result ? $result['id'] : null;
}

try {
    $database = new Database();
    $conn = $database->getConnection();
    
    $token = $_GET['session_token'] ?? null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
    $weekStart = $_GET['week_start_date'] ?? null;
    
    if (!$token) {
        echo json_encode([
            'success' => false,
            'message' => 'Session token is required'
        ]);
        exit();
    }
    
    $userId = verifyToken($token, $conn);
    if (!$userId) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid or expired session token'
        ]);
        exit();
    }
    
    // Get scratch card transactions
    if ($weekStart) {
        // Get transactions for specific week
        $stmt = $conn->prepare("SELECT * FROM scratch_card_transactions WHERE user_id = ? AND week_start_date = ? ORDER BY scratch_date DESC, created_at DESC LIMIT ?");
        $stmt->execute([$userId, $weekStart, $limit]);
    } else {
        // Get all recent transactions
        $stmt = $conn->prepare("SELECT * FROM scratch_card_transactions WHERE user_id = ? ORDER BY created_at DESC LIMIT ?");
        $stmt->execute([$userId, $limit]);
    }
    
    $transactions = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // Format transactions
    $formattedTransactions = [];
    foreach ($transactions as $transaction) {
        $formattedTransactions[] = [
            'id' => (int)$transaction['id'],
            'amount' => floatval($transaction['amount']),
            'day_number' => (int)$transaction['day_number'],
            'week_start_date' => $transaction['week_start_date'],
            'scratch_date' => $transaction['scratch_date'],
            'transaction_type' => $transaction['transaction_type'],
            'description' => $transaction['description'],
            'created_at' => $transaction['created_at']
        ];
    }
    
    echo json_encode([
        'success' => true,
        'transactions' => $formattedTransactions,
        'total' => count($formattedTransactions)
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>

