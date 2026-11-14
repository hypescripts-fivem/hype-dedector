-- hype-dedector
-- Run once on the server database. Safe to re-run: every statement skips what already exists.
-- Requires MySQL 5.7+ or MariaDB 10.2+ (JSON columns).

-- Detectors placed in the world. `categories` is a JSON array of Config.Categories values
CREATE TABLE IF NOT EXISTS `hype_dedector_detectors` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(64) NOT NULL,
    `area` VARCHAR(64) NOT NULL DEFAULT '',
    `x` FLOAT NOT NULL,
    `y` FLOAT NOT NULL,
    `z` FLOAT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0,
    `categories` JSON DEFAULT NULL,
    -- 1: alarms are sent to Config.Alert.server (police / security), 0: the detector only beeps and logs
    `alert` TINYINT(1) NOT NULL DEFAULT 1,
    `status` ENUM('active', 'disabled') NOT NULL DEFAULT 'active',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One row per alarm. What set it off is never stored (roleplay rules)
CREATE TABLE IF NOT EXISTS `hype_dedector_logs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `detector_id` INT UNSIGNED NOT NULL,
    `identifier` VARCHAR(64) NOT NULL DEFAULT '',
    `name` VARCHAR(64) NOT NULL DEFAULT '',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_detector` (`detector_id`),
    KEY `idx_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin menu settings, JSON encoded values. Missing keys fall back to Config.DefaultSettings
CREATE TABLE IF NOT EXISTS `hype_dedector_settings` (
    `key` VARCHAR(64) NOT NULL,
    `value` TEXT NOT NULL,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
