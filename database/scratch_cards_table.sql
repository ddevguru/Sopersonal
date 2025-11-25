-- Table to store scratch card configurations
CREATE TABLE IF NOT EXISTS `scratch_cards` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `contest_id` INT(11) DEFAULT NULL,
  `contest_type` ENUM('mega', 'mini') DEFAULT NULL,
  `amount` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `min_amount` DECIMAL(10,2) NOT NULL DEFAULT 10.00,
  `max_amount` DECIMAL(10,2) NOT NULL DEFAULT 100.00,
  `is_active` TINYINT(1) DEFAULT 1,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `contest_id` (`contest_id`),
  KEY `contest_type` (`contest_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table to track user scratch card history (for weekly 7 days tracking)
CREATE TABLE IF NOT EXISTS `user_scratch_card_history` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `user_id` INT(11) NOT NULL,
  `contest_id` INT(11) DEFAULT NULL,
  `contest_type` ENUM('mega', 'mini') DEFAULT NULL,
  `amount` DECIMAL(10,2) NOT NULL,
  `scratch_date` DATE NOT NULL,
  `week_start_date` DATE NOT NULL,
  `day_number` TINYINT(1) NOT NULL COMMENT '1-7 for days of week',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_date` (`user_id`, `scratch_date`),
  KEY `user_id` (`user_id`),
  KEY `scratch_date` (`scratch_date`),
  KEY `week_start_date` (`week_start_date`),
  KEY `user_week` (`user_id`, `week_start_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert sample scratch card amounts (you can modify these)
INSERT INTO `scratch_cards` (`contest_id`, `contest_type`, `min_amount`, `max_amount`, `is_active`) VALUES
(NULL, 'mega', 20.00, 50.00, 1),
(NULL, 'mini', 10.00, 30.00, 1);

-- Note: If contest_id is NULL, the scratch card applies to all contests of that type
-- If contest_id is set, it applies only to that specific contest
