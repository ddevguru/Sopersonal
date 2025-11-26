-- Safe fix for scratch card table - handles existing columns
-- Run these commands one by one, skip if you get "Duplicate column name" error

-- Step 1: Add week_start_date (skip if column already exists)
ALTER TABLE `user_scratch_card_history` 
ADD COLUMN `week_start_date` DATE NOT NULL DEFAULT (DATE_SUB(CURDATE(), INTERVAL WEEKDAY(CURDATE()) DAY)) 
AFTER `scratch_date`;

-- If Step 1 gives "Duplicate column name" error, the column exists - continue to Step 2

-- Step 2: Update week_start_date for existing records (if needed)
UPDATE `user_scratch_card_history` 
SET `week_start_date` = DATE_SUB(`scratch_date`, INTERVAL WEEKDAY(`scratch_date`) DAY)
WHERE `week_start_date` IS NULL OR `week_start_date` = '0000-00-00' OR `week_start_date` = '1970-01-01';

-- Step 3: Add day_number (skip if column already exists)
ALTER TABLE `user_scratch_card_history` 
ADD COLUMN `day_number` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1-7 for days of week' 
AFTER `week_start_date`;

-- If Step 3 gives "Duplicate column name" error, the column exists - continue to Step 4

-- Step 4: Update day_number for existing records (if needed)
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

-- Step 5: Verify table structure
DESCRIBE `user_scratch_card_history`;

