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
    $dayOfWeek = $date->format('N');
    $date->modify('-' . ($dayOfWeek - 1) . ' days');
    return $date->format('Y-m-d');
}

try {
    $database = new Database();
    $conn = $database->getConnection();
    
    $token = $_POST['session_token'] ?? null;
    $rewardType = $_POST['reward_type'] ?? 'Better Luck Next Time';
    $rewardValue = $_POST['reward_value'] ?? null;
    
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
    
    $today = date('Y-m-d');
    $weekStart = getWeekStartDate($today);
    
    // Check eligibility and if already spun
    $stmt = $conn->prepare("SELECT matches_played, is_eligible, has_spun FROM weekly_spin_wheel_eligibility WHERE user_id = ? AND week_start_date = ?");
    $stmt->execute([$userId, $weekStart]);
    $eligibility = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$eligibility) {
        echo json_encode([
            'success' => false,
            'message' => 'No eligibility record found. Please play 7 matches first.'
        ]);
        exit();
    }
    
    if ($eligibility['is_eligible'] != 1) {
        echo json_encode([
            'success' => false,
            'message' => 'You are not eligible. Play 7 matches to unlock weekly spin wheel.'
        ]);
        exit();
    }
    
    if ($eligibility['has_spun'] == 1) {
        echo json_encode([
            'success' => false,
            'message' => 'You have already spun this week. Next spin available next week!'
        ]);
        exit();
    }
    
    // Mark as spun and record transaction
    $conn->beginTransaction();
    try {
        // Update eligibility record
        $stmt = $conn->prepare("UPDATE weekly_spin_wheel_eligibility SET has_spun = 1, spin_date = ? WHERE user_id = ? AND week_start_date = ?");
        $stmt->execute([$today, $userId, $weekStart]);
        
        // Record transaction
        $stmt = $conn->prepare("INSERT INTO weekly_spin_wheel_transactions (user_id, reward_type, reward_value, week_start_date, spin_date, matches_played) VALUES (?, ?, ?, ?, ?, ?)");
        $stmt->execute([$userId, $rewardType, $rewardValue, $weekStart, $today, $eligibility['matches_played']]);
        
        $conn->commit();
        
        echo json_encode([
            'success' => true,
            'message' => 'Spin recorded successfully',
            'reward_type' => $rewardType,
            'reward_value' => $rewardValue,
            'matches_played' => $eligibility['matches_played']
        ]);
    } catch (Exception $e) {
        $conn->rollBack();
        throw $e;
    }
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>

