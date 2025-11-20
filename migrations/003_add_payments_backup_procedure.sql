-- Migration: Add payments backup procedure
-- Run order: after 001_add_router_id.sql and 002_add_ppp_profile_pricing.sql

USE pppoe_monitor;

-- Buat prosedur untuk backup payments dengan informasi username
DELIMITER //

CREATE PROCEDURE BackupPaymentsForRouter(IN router_id_param VARCHAR(100))
BEGIN
    DECLARE backup_table_name VARCHAR(255);
    DECLARE sql_stmt TEXT;
    
    -- Buat nama tabel backup dengan timestamp
    SET backup_table_name = CONCAT('payments_backup_', DATE_FORMAT(NOW(), '%Y%m%d_%H%i%s'));
    
    -- Buat tabel backup dengan data payments dan username
    SET @sql = CONCAT('CREATE TABLE ', backup_table_name, ' AS 
        SELECT p.*, u.username, NOW() as backup_timestamp 
        FROM payments p 
        LEFT JOIN users u ON p.user_id = u.id 
        WHERE p.router_id = ''', router_id_param, '''');
    
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
    
    -- Kembalikan nama tabel backup yang dibuat
    SELECT backup_table_name as backup_table;
END//

DELIMITER ;

-- Contoh penggunaan:
-- CALL BackupPaymentsForRouter('YOUR_ROUTER_ID');
