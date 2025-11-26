-- Table to track user spin wheel history (for weekly 7 days tracking)
-- Standalone spin wheel - NOT linked to any contest
CREATE TABLE IF NOT EXISTS `user_spin_wheel_history` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `spin_date` DATE NOT NULL,
  `week_start_date` DATE NOT NULL,
  `day_number` TINYINT(1) NOT NULL COMMENT '1-7 for days of week',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_date` (`user_id`, `spin_date`),
  KEY `user_id` (`user_id`),
  KEY `spin_date` (`spin_date`),
  KEY `week_start_date` (`week_start_date`),
  KEY `user_week` (`user_id`, `week_start_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table to store spin wheel transactions/winnings for logged in users
-- This is the main table for storing daily spin wheel winnings
CREATE TABLE IF NOT EXISTS `spin_wheel_transactions` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) NOT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `day_number` TINYINT(1) NOT NULL COMMENT '1-7 for days of week',
  `week_start_date` DATE NOT NULL,
  `spin_date` DATE NOT NULL,
  `transaction_type` ENUM('credit', 'debit') DEFAULT 'credit' COMMENT 'credit for winnings',
  `description` VARCHAR(255) DEFAULT 'Spin Wheel Reward',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `spin_date` (`spin_date`),
  KEY `week_start_date` (`week_start_date`),
  KEY `user_week` (`user_id`, `week_start_date`),
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Note: Spin wheel is standalone and not linked to any contest
-- Progressive amounts: Day 1 = ₹5, Day 2 = ₹10, ..., Day 7 = ₹35
-- If user misses any day, streak resets to Day 1

