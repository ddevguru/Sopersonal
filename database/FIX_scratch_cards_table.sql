-- Fix for "Column not found: day_number" and "week_start_date" errors
-- Run these SQL commands in order to add missing columns

-- Step 1: Add week_start_date column first (if it doesn't exist)
-- Check if week_start_date exists, if not add it
ALTER TABLE `user_scratch_card_history` 
ADD COLUMN `week_start_date` DATE NOT NULL DEFAULT (DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)) 
AFTER `scratch_date`;

-- Step 2: Update existing records to have week_start_date (if any exist)
-- This calculates Monday of the week for each scratch_date
UPDATE `user_scratch_card_history` 
SET `week_start_date` = DATE_SUB(`scratch_date`, INTERVAL WEEKDAY(`scratch_date`) DAY)
WHERE `week_start_date` IS NULL OR `week_start_date` = '0000-00-00';

-- Step 3: Add day_number column after week_start_date
ALTER TABLE `user_scratch_card_history` 
ADD COLUMN `day_number` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1-7 for days of week' 
AFTER `week_start_date`;

-- Step 4: Update existing records to have day_number (if any exist)
-- This calculates day of week (1=Monday, 7=Sunday) for each scratch_date
UPDATE `user_scratch_card_history` 
SET `day_number` = CASE 
    WHEN WEEKDAY(`scratch_date`) = 0 THEN 1  -- Monday
    WHEN WEEKDAY(`scratch_date`) = 1 THEN 2  -- Tuesday
    WHEN WEEKDAY(`scratch_date`) = 2 THEN 3  -- Wednesday
    WHEN WEEKDAY(`scratch_date`) = 3 THEN 4  -- Thursday
    WHEN WEEKDAY(`scratch_date`) = 4 THEN 5  -- Friday
    WHEN WEEKDAY(`scratch_date`) = 5 THEN 6  -- Saturday
    WHEN WEEKDAY(`scratch_date`) = 6 THEN 7  -- Sunday
    ELSE 1
END
WHERE `day_number` IS NULL OR `day_number` = 0;

-- Step 5: Verify the table structure
-- DESCRIBE `user_scratch_card_history`;

-- Note: If you get "Duplicate column name" error, it means the column already exists
-- In that case, skip that step and continue with the next one
