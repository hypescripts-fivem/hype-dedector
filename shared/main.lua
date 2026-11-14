lib.locale()

-- Global so the functions inside the config (Alert.client, Alert.server) can read it too
Config = require "config.config"

Queries = {
    -- Detectors
    GetDetectors = "SELECT id, name, area, x, y, z, heading, categories, alert, status FROM hype_dedector_detectors ORDER BY id DESC",
    GetDetector = "SELECT id, name, area, x, y, z, heading, categories, alert, status FROM hype_dedector_detectors WHERE id = ?",
    -- The first parameter is a detector id to skip (the one being edited), 0 when creating
    GetDetectorNearPosition = "SELECT id FROM hype_dedector_detectors WHERE id <> ? AND POW(x - ?, 2) + POW(y - ?, 2) + POW(z - ?, 2) < POW(?, 2) LIMIT 1",
    InsertDetector = "INSERT INTO hype_dedector_detectors (name, area, x, y, z, heading, categories, alert) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
    UpdateDetector = "UPDATE hype_dedector_detectors SET name = ?, area = ?, x = ?, y = ?, z = ?, heading = ?, categories = ?, alert = ? WHERE id = ?",
    SetDetectorStatus = "UPDATE hype_dedector_detectors SET status = ? WHERE id = ?",
    DeleteDetector = "DELETE FROM hype_dedector_detectors WHERE id = ?",
    -- Databases created before the per-detector alert switch get the column on start (MySQL has no ADD COLUMN IF NOT EXISTS)
    HasAlertColumn = "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'hype_dedector_detectors' AND COLUMN_NAME = 'alert'",
    AddAlertColumn = "ALTER TABLE hype_dedector_detectors ADD COLUMN `alert` TINYINT(1) NOT NULL DEFAULT 1 AFTER `categories`",

    -- Alarm logs. There is deliberately no column for what was found
    InsertLog = "INSERT INTO hype_dedector_logs (detector_id, identifier, name) VALUES (?, ?, ?)",
    -- The first two parameters are the same detector id, 0 for every detector
    GetLogs = "SELECT l.id, l.detector_id, d.name AS detector_name, l.name, UNIX_TIMESTAMP(l.created_at) AS created_at FROM hype_dedector_logs l LEFT JOIN hype_dedector_detectors d ON d.id = l.detector_id WHERE (? = 0 OR l.detector_id = ?) ORDER BY l.id DESC LIMIT ? OFFSET ?",
    CountAlarmsToday = "SELECT COUNT(*) FROM hype_dedector_logs WHERE created_at >= CURDATE()",
    GetAlarmsTodayByDetector = "SELECT detector_id, COUNT(*) AS count FROM hype_dedector_logs WHERE created_at >= CURDATE() GROUP BY detector_id",
    -- The interval is days before today, so pass statsDays - 1
    GetDailyAlarms = "SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS day, COUNT(*) AS alarms FROM hype_dedector_logs WHERE created_at >= CURDATE() - INTERVAL ? DAY GROUP BY day ORDER BY day",
    PurgeLogs = "DELETE FROM hype_dedector_logs WHERE created_at < NOW() - INTERVAL ? DAY",
    DeleteDetectorLogs = "DELETE FROM hype_dedector_logs WHERE detector_id = ?",

    -- Settings
    GetSettings = "SELECT `key`, `value` FROM hype_dedector_settings",
    -- Settings that moved out of the database (the webhook now lives in config/sv-config.lua)
    DeleteSetting = "DELETE FROM hype_dedector_settings WHERE `key` = ?",
    SaveSetting = "INSERT INTO hype_dedector_settings (`key`, `value`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)",
}
