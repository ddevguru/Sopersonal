-- Table to track weekly spin wheel eligibility based on matches played
-- User needs to play 7 matches (mini or mega contests) in a week to be eligible
CREATE TABLE IF NOT EXISTS `weekly_spin_wheel_eligibility` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) NOT NULL,
  `week_start_date` DATE NOT NULL COMMENT 'Monday of the week',
  `matches_played` INT(11) NOT NULL DEFAULT 0 COMMENT 'Number of matches played this week',
  `is_eligible` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 if eligible (7 matches played), 0 otherwise',
  `has_spun` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 if user has spun this week, 0 otherwise',
  `spin_date` DATE NULL COMMENT 'Date when user spun the wheel',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_week` (`user_id`, `week_start_date`),
  KEY `user_id` (`user_id`),
  KEY `week_start_date` (`week_start_date`),
  KEY `is_eligible` (`is_eligible`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table to track contest plays for weekly spin wheel eligibility
-- Tracks each contest join/submission to count matches played
CREATE TABLE IF NOT EXISTS `user_contest_plays` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) NOT NULL,
  `contest_id` INT(11) NOT NULL,
  `contest_type` ENUM('mini', 'mega') NOT NULL,
  `play_date` DATE NOT NULL,
  `week_start_date` DATE NOT NULL COMMENT 'Monday of the week',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `contest_id` (`contest_id`),
  KEY `play_date` (`play_date`),
  KEY `week_start_date` (`week_start_date`),
  KEY `user_week` (`user_id`, `week_start_date`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table to store weekly spin wheel transactions/winnings
CREATE TABLE IF NOT EXISTS `weekly_spin_wheel_transactions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) NOT NULL,
  `reward_type` VARCHAR(100) NOT NULL COMMENT 'Type of reward won (e.g., Alexa, Gift Card, etc.)',
  `reward_value` VARCHAR(255) NULL COMMENT 'Value of reward if applicable',
  `week_start_date` DATE NOT NULL,
  `spin_date` DATE NOT NULL,
  `matches_played` INT(11) NOT NULL COMMENT 'Number of matches played to become eligible',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `spin_date` (`spin_date`),
  KEY `week_start_date` (`week_start_date`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Note: User needs to play 7 matches (mini or mega contests) in a week to be eligible
-- Matches can be played in 1 day, 2 days, or spread across the week - all valid
-- Once eligible and spun, next spin available in next week

