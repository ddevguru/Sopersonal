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
    
    // Get all spins for this week
    $stmt = $conn->prepare("SELECT day_number, spin_date, amount FROM user_spin_wheel_history WHERE user_id = ? AND week_start_date = ? ORDER BY day_number");
    $stmt->execute([$userId, $weekStart]);
    $spins = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    $spunDays = [];
    $totalAmount = 0;
    foreach ($spins as $spin) {
        $spunDays[] = (int)$spin['day_number'];
        $totalAmount += floatval($spin['amount']);
    }
    
    // Check if user missed any previous day
    $hasMissedDay = false;
    $currentStreakDay = 1;
    
    if ($dayNumber > 1) {
        // Check if all previous days were spun consecutively
        for ($i = 1; $i < $dayNumber; $i++) {
            if (!in_array($i, $spunDays)) {
                $hasMissedDay = true;
                break;
            }
        }
        
        // If no missed days, current streak day is the current day
        if (!$hasMissedDay) {
            $currentStreakDay = $dayNumber;
        } else {
            // Reset to day 1 if any day was missed
            $currentStreakDay = 1;
        }
    } else {
        // It's day 1 (Monday)
        if (in_array(1, $spunDays)) {
            $currentStreakDay = 1; // Already spun, will be day 2 tomorrow
        } else {
            $currentStreakDay = 1; // Can spin day 1
        }
    }
    
    return [
        'week_start_date' => $weekStart,
        'current_day' => $dayNumber,
        'spun_days' => $spunDays,
        'total_spun' => count($spunDays),
        'total_amount' => $totalAmount,
        'can_spin_today' => !in_array($dayNumber, $spunDays),
        'current_streak_day' => $currentStreakDay,
        'has_missed_day' => $hasMissedDay
    ];
}

function hasSpunToday($userId, $conn) {
    $today = date('Y-m-d');
    $stmt = $conn->prepare("SELECT id FROM user_spin_wheel_history WHERE user_id = ? AND spin_date = ?");
    $stmt->execute([$userId, $today]);
    return $stmt->rowCount() > 0;
}

function getSpinWheelAmount($userId, $conn) {
    // Get weekly progress to determine current streak day
    $weeklyProgress = getWeeklyProgress($userId, $conn);
    $currentStreakDay = $weeklyProgress['current_streak_day'];
    
    // Progressive amount: Day 1 = ₹5, Day 2 = ₹10, ..., Day 7 = ₹35
    // Formula: amount = day_number * 5
    $amount = $currentStreakDay * 5;
    
    return round($amount, 2);
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
    
    // Get weekly progress
    $weeklyProgress = getWeeklyProgress($userId, $conn);
    
    // Check if user has already spun today
    $canSpinToday = $weeklyProgress['can_spin_today'];
    
    if ($canSpinToday) {
        // Get spin wheel amount based on progressive system
        $amount = getSpinWheelAmount($userId, $conn);
        $currentStreakDay = $weeklyProgress['current_streak_day'];
        
        echo json_encode([
            'success' => true,
            'amount' => $amount,
            'can_spin_today' => true,
            'weekly_progress' => $weeklyProgress,
            'current_streak_day' => $currentStreakDay,
            'message' => 'Spin wheel available'
        ]);
    } else {
        // User has already spun today
        echo json_encode([
            'success' => true,
            'amount' => 0,
            'can_spin_today' => false,
            'weekly_progress' => $weeklyProgress,
            'message' => 'You have already spun the wheel today. Come back tomorrow!'
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

