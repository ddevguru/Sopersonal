<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
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
        'total_amount' => $totalAmount,
        'can_scratch_today' => !in_array($dayNumber, $scratchedDays)
    ];
}

function hasScratchedToday($userId, $conn) {
    $today = date('Y-m-d');
    $stmt = $conn->prepare("SELECT id FROM user_scratch_card_history WHERE user_id = ? AND scratch_date = ?");
    $stmt->execute([$userId, $today]);
    return $stmt->rowCount() > 0;
}

function getScratchCardAmount($contestId, $contestType, $conn) {
    // First try to get contest-specific scratch card
    if ($contestId) {
        $stmt = $conn->prepare("SELECT min_amount, max_amount FROM scratch_cards WHERE contest_id = ? AND contest_type = ? AND is_active = 1 LIMIT 1");
        $stmt->execute([$contestId, $contestType]);
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result) {
            $minAmount = floatval($result['min_amount']);
            $maxAmount = floatval($result['max_amount']);
            // Generate random amount between min and max
            return round(rand($minAmount * 100, $maxAmount * 100) / 100, 2);
        }
    }
    
    // If no contest-specific card, get default for contest type
    $stmt = $conn->prepare("SELECT min_amount, max_amount FROM scratch_cards WHERE contest_id IS NULL AND contest_type = ? AND is_active = 1 LIMIT 1");
    $stmt->execute([$contestType]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($result) {
        $minAmount = floatval($result['min_amount']);
        $maxAmount = floatval($result['max_amount']);
        // Generate random amount between min and max
        return round(rand($minAmount * 100, $maxAmount * 100) / 100, 2);
    }
    
    // Default amount if no configuration found
    return round(rand(1000, 5000) / 100, 2); // 10.00 to 50.00
}

try {
    $database = new Database();
    $conn = $database->getConnection();
    
    $token = $_GET['session_token'] ?? null;
    $contestId = isset($_GET['contest_id']) ? intval($_GET['contest_id']) : null;
    $contestType = $_GET['contest_type'] ?? 'mini';
    
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
    
    // Get weekly progress
    $weeklyProgress = getWeeklyProgress($userId, $conn);
    
    // Check if user has already scratched today
    $canScratchToday = $weeklyProgress['can_scratch_today'];
    
    if ($canScratchToday) {
        // Get scratch card amount
        $amount = getScratchCardAmount($contestId, $contestType, $conn);
        
        echo json_encode([
            'success' => true,
            'amount' => $amount,
            'can_scratch_today' => true,
            'weekly_progress' => $weeklyProgress,
            'message' => 'Scratch card available'
        ]);
    } else {
        // User has already scratched today
        echo json_encode([
            'success' => true,
            'amount' => 0,
            'can_scratch_today' => false,
            'weekly_progress' => $weeklyProgress,
            'message' => 'You have already scratched a card today. Come back tomorrow!'
        ]);
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>
