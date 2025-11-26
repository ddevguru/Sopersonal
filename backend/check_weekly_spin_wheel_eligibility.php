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

function getWeekEndDate($date = null) {
    if ($date === null) {
        $date = new DateTime();
    } else {
        $date = new DateTime($date);
    }
    $dayOfWeek = $date->format('N');
    $date->modify('-' . ($dayOfWeek - 1) . ' days'); // Go to Monday
    $date->modify('+6 days'); // Go to Sunday
    return $date->format('Y-m-d');
}

function getDaysUntilWeekEnd($weekEndDate) {
    $today = new DateTime();
    $endDate = new DateTime($weekEndDate);
    $diff = $today->diff($endDate);
    return max(0, $diff->days);
}

function updateEligibility($userId, $conn) {
    $weekStart = getWeekStartDate();
    
    // Count matches played this week
    $stmt = $conn->prepare("SELECT COUNT(DISTINCT contest_id) as match_count FROM user_contest_plays WHERE user_id = ? AND week_start_date = ?");
    $stmt->execute([$userId, $weekStart]);
    $result = $stmt->fetch(PDO::FETCH_ASSOC);
    $matchesPlayed = (int)($result['match_count'] ?? 0);
    
    // Check if eligible (7 matches played)
    $isEligible = $matchesPlayed >= 7 ? 1 : 0;
    
    // Get or create eligibility record
    $stmt = $conn->prepare("SELECT * FROM weekly_spin_wheel_eligibility WHERE user_id = ? AND week_start_date = ?");
    $stmt->execute([$userId, $weekStart]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($existing) {
        // Update existing record
        $stmt = $conn->prepare("UPDATE weekly_spin_wheel_eligibility SET matches_played = ?, is_eligible = ? WHERE user_id = ? AND week_start_date = ?");
        $stmt->execute([$matchesPlayed, $isEligible, $userId, $weekStart]);
    } else {
        // Create new record
        $stmt = $conn->prepare("INSERT INTO weekly_spin_wheel_eligibility (user_id, week_start_date, matches_played, is_eligible) VALUES (?, ?, ?, ?)");
        $stmt->execute([$userId, $weekStart, $matchesPlayed, $isEligible]);
    }
    
    return [
        'matches_played' => $matchesPlayed,
        'is_eligible' => $isEligible,
        'matches_remaining' => max(0, 7 - $matchesPlayed)
    ];
}

try {
    $database = new Database();
    $conn = $database->getConnection();
    
    $token = $_GET['session_token'] ?? null;
    
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
    
    // Update eligibility based on current matches played
    $eligibility = updateEligibility($userId, $conn);
    
    // Get current week info
    $weekStart = getWeekStartDate();
    $weekEnd = getWeekEndDate();
    $daysRemaining = getDaysUntilWeekEnd($weekEnd);
    
    // Check if user has already spun this week
    $stmt = $conn->prepare("SELECT has_spun, spin_date FROM weekly_spin_wheel_eligibility WHERE user_id = ? AND week_start_date = ?");
    $stmt->execute([$userId, $weekStart]);
    $spinRecord = $stmt->fetch(PDO::FETCH_ASSOC);
    $hasSpun = $spinRecord ? (bool)$spinRecord['has_spun'] : false;
    
    echo json_encode([
        'success' => true,
        'matches_played' => $eligibility['matches_played'],
        'matches_remaining' => $eligibility['matches_remaining'],
        'is_eligible' => $eligibility['is_eligible'] == 1,
        'has_spun' => $hasSpun,
        'week_start_date' => $weekStart,
        'week_end_date' => $weekEnd,
        'days_remaining' => $daysRemaining,
        'can_spin' => $eligibility['is_eligible'] == 1 && !$hasSpun,
        'message' => $eligibility['matches_remaining'] > 0 
            ? "Play {$eligibility['matches_remaining']} more match(es) to unlock weekly spin wheel!"
            : ($hasSpun ? "You have already spun this week. Next spin available next week!" : "You are eligible to spin!")
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>

