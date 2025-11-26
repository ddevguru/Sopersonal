-- ALTER TABLE command to add missing columns if table already exists
-- Run this if you get "Column not found: day_number" error

-- Check if day_number column exists, if not add it
ALTER TABLE `user_scratch_card_history` 
ADD COLUMN IF NOT EXISTS `day_number` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1-7 for days of week' AFTER `week_start_date`;

-- If the above doesn't work (MySQL version doesn't support IF NOT EXISTS), use this:
-- ALTER TABLE `user_scratch_card_history` 
-- ADD COLUMN `day_number` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1-7 for days of week' AFTER `week_start_date`;

-- Note: If you get "Duplicate column name" error, it means the column already exists
-- In that case, just verify the table structure matches the scratch_cards_table.sql file

