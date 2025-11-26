<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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

function hasSpunToday($userId, $conn) {
    $today = date('Y-m-d');
    $stmt = $conn->prepare("SELECT id FROM user_spin_wheel_history WHERE user_id = ? AND spin_date = ?");
    $stmt->execute([$userId, $today]);
    return $stmt->rowCount() > 0;
}

function updateWallet($userId, $amount, $conn) {
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
        
        // Record in spin wheel history with weekly tracking
        $today = date('Y-m-d');
        $weekStart = getWeekStartDate($today);
        $dayNumber = getDayNumber($today);
        
        // Insert into spin wheel history
        $stmt = $conn->prepare("INSERT INTO user_spin_wheel_history (user_id, amount, spin_date, week_start_date, day_number) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$userId, $amount, $today, $weekStart, $dayNumber]);
        
        // Insert into spin wheel transactions table for logged in users (MAIN TABLE FOR WINNINGS)
        $stmt = $conn->prepare("INSERT INTO spin_wheel_transactions (user_id, amount, day_number, week_start_date, spin_date, transaction_type, description) VALUES (?, ?, ?, ?, ?, 'credit', ?)");
        $description = "Spin Wheel Day $dayNumber Reward - ₹" . number_format($amount, 2);
        $stmt->execute([$userId, $amount, $dayNumber, $weekStart, $today, $description]);
        
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
        'current_streak_day' => $currentStreakDay,
        'has_missed_day' => $hasMissedDay
    ];
}

try {
    $database = new Database();
    $conn = $database->getConnection();
    
    $token = $_POST['session_token'] ?? null;
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
    
    // Check if user has already spun today
    if (hasSpunToday($userId, $conn)) {
        echo json_encode([
            'success' => false,
            'message' => 'You have already spun the wheel today. Come back tomorrow!'
        ]);
        exit();
    }
    
    // Update wallet and store in transactions table
    $result = updateWallet($userId, $amount, $conn);
    
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

