# Scratch Card Database Setup - Weekly Progressive System

## Installation Steps

1. **Create the database tables:**
   - Run the SQL file `scratch_cards_table.sql` in your MySQL database
   - This will create three tables:
     - `scratch_cards` - Stores scratch card configurations
     - `user_scratch_card_history` - Tracks user scratch card usage (weekly 7 days tracking)
     - `scratch_card_transactions` - Stores all scratch card winnings/transactions for logged in users

2. **Database Configuration:**
   - The backend uses `db.php` from the config folder
   - Make sure `db.php` exists with your database credentials
   - The Database class should be available in `db.php`

3. **Upload PHP files:**
   - Upload `fetch_scratch_card_amount.php` to your server
   - Upload `update_wallet_from_scratch_card.php` to your server
   - Upload `get_scratch_card_transactions.php` to your server (optional - for viewing transaction history)
   - Make sure `db.php` is accessible from these files (usually in `config/db.php`)

## Database Tables

### scratch_cards
Stores scratch card configurations:
- `id` - Primary key
- `contest_id` - Contest ID (NULL for all contests of that type)
- `contest_type` - 'mega' or 'mini'
- `min_amount` - Minimum scratch card amount (not used in progressive system)
- `max_amount` - Maximum scratch card amount (not used in progressive system)
- `is_active` - Whether the scratch card is active

### user_scratch_card_history
Tracks user scratch card history for weekly 7 days:
- `id` - Primary key
- `user_id` - User ID
- `contest_id` - Contest ID (optional)
- `contest_type` - 'mega' or 'mini'
- `amount` - Amount won
- `scratch_date` - Date when scratched
- `week_start_date` - Monday date of the week (for weekly tracking)
- `day_number` - Day of week (1=Monday to 7=Sunday)
- Unique constraint on (user_id, scratch_date) ensures one scratch per day

### scratch_card_transactions
Stores all scratch card winnings for logged in users:
- `id` - Primary key
- `user_id` - User ID (Foreign key to users table)
- `amount` - Amount won (DECIMAL 10,2)
- `day_number` - Day of week when scratched (1-7)
- `week_start_date` - Monday date of the week
- `scratch_date` - Date when scratched
- `transaction_type` - 'credit' for winnings
- `description` - Description of the transaction
- `created_at` - Timestamp when transaction was created

## Progressive Amount System

### Weekly Progressive Rewards:
- **Day 1 (Monday)**: ₹5
- **Day 2 (Tuesday)**: ₹10
- **Day 3 (Wednesday)**: ₹15
- **Day 4 (Thursday)**: ₹20
- **Day 5 (Friday)**: ₹25
- **Day 6 (Saturday)**: ₹30
- **Day 7 (Sunday)**: ₹35

### Reset Logic:
- If user misses any day, the streak resets to Day 1 (₹5)
- New week starts every Monday
- Amount formula: `amount = day_number * 5`

## API Endpoints

### 1. Fetch Scratch Card Amount
**URL:** `https://sopersonal.in/fetch_scratch_card_amount.php`

**Method:** GET

**Parameters:**
- `session_token` - User session token
- `contest_id` - Contest ID (optional)
- `contest_type` - 'mega' or 'mini'

**Response:**
```json
{
  "success": true,
  "amount": 15.00,
  "can_scratch_today": true,
  "current_streak_day": 3,
  "weekly_progress": {
    "week_start_date": "2025-01-27",
    "current_day": 3,
    "scratched_days": [1, 2],
    "total_scratched": 2,
    "total_amount": 15.00,
    "current_streak_day": 3,
    "has_missed_day": false
  },
  "message": "Scratch card available"
}
```

### 2. Update Wallet from Scratch Card
**URL:** `https://sopersonal.in/update_wallet_from_scratch_card.php`

**Method:** POST

**Parameters:**
- `session_token` - User session token
- `contest_id` - Contest ID (optional)
- `contest_type` - 'mega' or 'mini'
- `amount` - Amount to add to wallet

**Response:**
```json
{
  "success": true,
  "message": "Amount added to wallet successfully",
  "new_balance": 1250.50,
  "amount_added": 15.00,
  "weekly_progress": {
    "week_start_date": "2025-01-27",
    "current_day": 3,
    "scratched_days": [1, 2, 3],
    "total_scratched": 3,
    "total_amount": 30.00,
    "current_streak_day": 3,
    "has_missed_day": false
  }
}
```

### 3. Get Scratch Card Transactions (Optional)
**URL:** `https://sopersonal.in/get_scratch_card_transactions.php`

**Method:** GET

**Parameters:**
- `session_token` - User session token
- `limit` - Number of transactions to fetch (default: 50)
- `week_start_date` - Optional: Filter by week start date

**Response:**
```json
{
  "success": true,
  "transactions": [
    {
      "id": 1,
      "amount": 15.00,
      "day_number": 3,
      "week_start_date": "2025-01-27",
      "scratch_date": "2025-01-29",
      "transaction_type": "credit",
      "description": "Scratch Card Day 3 Reward - ₹15.00",
      "created_at": "2025-01-29 10:30:00"
    }
  ],
  "total": 1
}
```

## Features

- **Progressive Rewards**: Amount increases each day (₹5 to ₹35)
- **Streak System**: Must scratch consecutively to progress
- **Reset on Miss**: Missing any day resets to Day 1
- **Transaction History**: All winnings stored in separate table
- **Weekly Reset**: New cycle every Monday

## Example Queries

### Get user's total scratch card winnings:
```sql
SELECT SUM(amount) as total_winnings 
FROM scratch_card_transactions 
WHERE user_id = 1 AND transaction_type = 'credit';
```

### Get user's weekly progress:
```sql
SELECT week_start_date, SUM(amount) as weekly_total, COUNT(*) as days_scratched
FROM scratch_card_transactions 
WHERE user_id = 1 AND week_start_date = '2025-01-27'
GROUP BY week_start_date;
```

### Get user's transaction history:
```sql
SELECT * FROM scratch_card_transactions 
WHERE user_id = 1 
ORDER BY created_at DESC 
LIMIT 20;
```
