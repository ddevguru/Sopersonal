<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once 'db.php';

function verifyToken($token, $conn) {
    $stmt = $conn->prepare("SELECT id FROM users WHERE session_token = ? AND status = 'online'");
    $stmt->execute([$token]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    return $result ? $result['id'] : null;
}

function getWeekStartDate($date = null) {
    if ($date === null) {
        $date = new DateTime();
    } else {
        $date = new DateTime($date);
    }
    // Get Monday of the week
    $dayOfWeek = $date->format('N'); // 1 (Monday) to 7 (Sunday)
    $date->modify('-' . ($dayOfWeek - 1) . ' days');
    return $date->format('Y-m-d');
}

function getDayNumber($date = null) {
    if ($date === null) {
        $date = new DateTime();
    } else {
        $date = new DateTime($date);
    }
    return (int)$date->format('N'); // 1 (Monday) to 7 (Sunday)
}

function hasScratchedToday($userId, $conn) {
    $today = date('Y-m-d');
    $stmt = $conn->prepare("SELECT id FROM user_scratch_card_history WHERE user_id = ? AND scratch_date = ?");
    $stmt->execute([$userId, $today]);
    return $stmt->rowCount() > 0;
}

function updateWallet($userId, $amount, $contestId, $contestType, $conn) {
    // Start transaction
    $conn->beginTransaction();
    
    try {
        // Get current balance
        $stmt = $conn->prepare("SELECT wallet_balance FROM users WHERE id = ? FOR UPDATE");
        $stmt->execute([$userId]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if (!$result) {
            throw new Exception("User not found");
        }
        
        $currentBalance = floatval($result['wallet_balance']);
        $newBalance = $currentBalance + floatval($amount);
        
        // Update wallet balance
        $stmt = $conn->prepare("UPDATE users SET wallet_balance = ? WHERE id = ?");
        $stmt->execute([$newBalance, $userId]);
        
        // Record in scratch card history with weekly tracking
        $today = date('Y-m-d');
        $weekStart = getWeekStartDate($today);
        $dayNumber = getDayNumber($today);
        
        $stmt = $conn->prepare("INSERT INTO user_scratch_card_history (user_id, contest_id, contest_type, amount, scratch_date, week_start_date, day_number) VALUES (?, ?, ?, ?, ?, ?, ?)");
        $stmt->execute([$userId, $contestId, $contestType, $amount, $today, $weekStart, $dayNumber]);
        
        // Commit transaction
        $conn->commit();
        
        return [
            'success' => true,
            'new_balance' => $newBalance,
            'amount_added' => $amount,
            'day_number' => $dayNumber,
            'week_start_date' => $weekStart
        ];
        
    } catch (Exception $e) {
        // Rollback transaction
        $conn->rollBack();
        throw $e;
    }
}

function getWeeklyProgress($userId, $conn) {
    $weekStart = getWeekStartDate();
    $dayNumber = getDayNumber();
    
    // Get all scratches for this week
    $stmt = $conn->prepare("SELECT day_number, scratch_date, amount FROM user_scratch_card_history WHERE user_id = ? AND week_start_date = ? ORDER BY day_number");
    $stmt->execute([$userId, $weekStart]);
    $scratches = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $scratchedDays = [];
    $totalAmount = 0;
    foreach ($scratches as $scratch) {
        $scratchedDays[] = (int)$scratch['day_number'];
        $totalAmount += floatval($scratch['amount']);
    }
    
    return [
        'week_start_date' => $weekStart,
        'current_day' => $dayNumber,
        'scratched_days' => $scratchedDays,
        'total_scratched' => count($scratchedDays),
        'total_amount' => $totalAmount
    ];
}

try {
    $database = new Database();
    $conn = $database->getConnection();
    
    $token = $_POST['session_token'] ?? null;
    $contestId = isset($_POST['contest_id']) ? intval($_POST['contest_id']) : null;
    $contestType = $_POST['contest_type'] ?? 'mini';
    $amount = isset($_POST['amount']) ? floatval($_POST['amount']) : 0;
    
    if (!$token) {
        echo json_encode([
            'success' => false,
            'message' => 'Session token is required'
        ]);
        exit();
    }
    
    if ($amount <= 0) {
        echo json_encode([
            'success' => false,
            'message' => 'Invalid amount'
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
    
    // Check if user has already scratched today
    if (hasScratchedToday($userId, $conn)) {
        echo json_encode([
            'success' => false,
            'message' => 'You have already scratched a card today. Come back tomorrow!'
        ]);
        exit();
    }
    
    // Update wallet
    $result = updateWallet($userId, $amount, $contestId, $contestType, $conn);
    
    // Get updated weekly progress
    $weeklyProgress = getWeeklyProgress($userId, $conn);
    
    echo json_encode([
        'success' => true,
        'message' => 'Amount added to wallet successfully',
        'new_balance' => $result['new_balance'],
        'amount_added' => $result['amount_added'],
        'weekly_progress' => $weeklyProgress
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>
