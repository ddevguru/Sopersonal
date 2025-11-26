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
    $contestId = isset($_POST['contest_id']) ? intval($_POST['contest_id']) : null;
    $contestType = $_POST['contest_type'] ?? null;
    
    if (!$token) {
        echo json_encode([
            'success' => false,
            'message' => 'Session token is required'
        ]);
        exit();
    }
    
    if (!$contestId || !$contestType) {
        echo json_encode([
            'success' => false,
            'message' => 'Contest ID and type are required'
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
    
    // Check if this contest play is already recorded
    $stmt = $conn->prepare("SELECT id FROM user_contest_plays WHERE user_id = ? AND contest_id = ? AND contest_type = ? AND play_date = ?");
    $stmt->execute([$userId, $contestId, $contestType, $today]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$existing) {
        // Record the contest play
        $stmt = $conn->prepare("INSERT INTO user_contest_plays (user_id, contest_id, contest_type, play_date, week_start_date) VALUES (?, ?, ?, ?, ?)");
        $stmt->execute([$userId, $contestId, $contestType, $today, $weekStart]);
    }
    
    // Update eligibility
    $weekStart = getWeekStartDate($today);
    
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
    
    $eligibility = [
        'matches_played' => $matchesPlayed,
        'is_eligible' => $isEligible,
        'matches_remaining' => max(0, 7 - $matchesPlayed)
    ];
    
    echo json_encode([
        'success' => true,
        'message' => 'Contest play recorded',
        'matches_played' => $eligibility['matches_played'],
        'matches_remaining' => $eligibility['matches_remaining'],
        'is_eligible' => $eligibility['is_eligible'] == 1
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Server error: ' . $e->getMessage()
    ]);
}
?>

