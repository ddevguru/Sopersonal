# Scratch Card Database Setup - Weekly 7 Days System

## Installation Steps

1. **Create the database tables:**
   - Run the SQL file `scratch_cards_table.sql` in your MySQL database
   - This will create two tables:
     - `scratch_cards` - Stores scratch card configurations
     - `user_scratch_card_history` - Tracks user scratch card usage (weekly 7 days tracking)

2. **Database Configuration:**
   - The backend uses `db.php` from the config folder
   - Make sure `db.php` exists with your database credentials
   - The Database class should be available in `db.php`

3. **Upload PHP files:**
   - Upload `fetch_scratch_card_amount.php` to your server
   - Upload `update_wallet_from_scratch_card.php` to your server
   - Make sure `db.php` is accessible from these files (usually in `config/db.php`)

## Database Tables

### scratch_cards
Stores scratch card configurations:
- `id` - Primary key
- `contest_id` - Contest ID (NULL for all contests of that type)
- `contest_type` - 'mega' or 'mini'
- `min_amount` - Minimum scratch card amount
- `max_amount` - Maximum scratch card amount
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

## Weekly System Features

- **7 Days Per Week:** Users can scratch one card per day for 7 days
- **Week Reset:** New week starts every Monday
- **Progress Tracking:** Tracks which days of the week have been scratched
- **Daily Limit:** Only one scratch per day (enforced by unique constraint)

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
  "amount": 25.50,
  "can_scratch_today": true,
  "weekly_progress": {
    "week_start_date": "2025-01-27",
    "current_day": 3,
    "scratched_days": [1, 2],
    "total_scratched": 2,
    "total_amount": 45.50
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
  "amount_added": 25.50,
  "weekly_progress": {
    "week_start_date": "2025-01-27",
    "current_day": 3,
    "scratched_days": [1, 2, 3],
    "total_scratched": 3,
    "total_amount": 71.00
  }
}
```

## Frontend Features

- **Weekly Progress Indicator:** Shows X/7 days scratched
- **Daily Status:** Shows if user can scratch today
- **Visual Progress:** 7 circles showing which days are completed
- **Golden Card Design:** Beautiful golden scratch card with circular reveal area

## Customization

To change scratch card amounts:
```sql
UPDATE scratch_cards 
SET min_amount = 15.00, max_amount = 50.00 
WHERE contest_type = 'mega';
```

To add contest-specific scratch cards:
```sql
INSERT INTO scratch_cards (contest_id, contest_type, min_amount, max_amount) 
VALUES (1, 'mega', 30.00, 100.00);
```

## Week Calculation

- Week starts on Monday (day 1)
- Week ends on Sunday (day 7)
- Each week resets automatically on Monday
- Users can scratch one card per day, maximum 7 cards per week
