-- =====================================================
-- Mikrotik PPPoE Monitor - Database Schema
-- =====================================================
-- Version: 1.0
-- Created: October 2024
-- Description: Schema untuk aplikasi monitoring PPPoE Mikrotik
-- =====================================================

-- Create database (if not exists)
CREATE DATABASE IF NOT EXISTS pppoe_monitor 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE pppoe_monitor;

-- =====================================================
-- Table: odp (Optical Distribution Point)
-- =====================================================
-- Menyimpan data lokasi ODP untuk tracking instalasi
-- =====================================================

CREATE TABLE IF NOT EXISTS odp (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL COMMENT 'Nama ODP',
  location VARCHAR(255) NOT NULL COMMENT 'Alamat lokasi ODP',
  maps_link TEXT DEFAULT NULL COMMENT 'Link Google Maps',
  type ENUM('splitter', 'ratio') NOT NULL COMMENT 'Tipe ODP: splitter atau ratio',
  splitter_type VARCHAR(10) DEFAULT NULL COMMENT 'Tipe splitter: 1:2, 1:4, 1:8, 1:16',
  ratio_used INT DEFAULT NULL COMMENT 'Jumlah port yang terpakai (untuk tipe ratio)',
  ratio_total INT DEFAULT NULL COMMENT 'Total port yang tersedia (untuk tipe ratio)',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_name (name),
  INDEX idx_type (type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabel untuk menyimpan data ODP (Optical Distribution Point)';

-- =====================================================
-- Table: users
-- =====================================================
-- Menyimpan data user PPPoE yang tersinkronisasi dari Mikrotik
-- =====================================================

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(100) NOT NULL UNIQUE COMMENT 'Username PPPoE (unique)',
  password VARCHAR(255) NOT NULL COMMENT 'Password PPPoE',
  profile VARCHAR(100) NOT NULL COMMENT 'Profile PPPoE dari Mikrotik',
  wa VARCHAR(20) DEFAULT NULL COMMENT 'Nomor WhatsApp pelanggan',
  maps TEXT DEFAULT NULL COMMENT 'Link Google Maps lokasi pelanggan',
  foto TEXT DEFAULT NULL COMMENT 'Path atau URL foto lokasi instalasi',
  tanggal_dibuat DATETIME DEFAULT NULL COMMENT 'Tanggal user dibuat',
  odp_id INT DEFAULT NULL COMMENT 'Foreign key ke tabel ODP',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_username (username),
  INDEX idx_profile (profile),
  INDEX idx_odp_id (odp_id),
  CONSTRAINT fk_users_odp FOREIGN KEY (odp_id) 
    REFERENCES odp(id) 
    ON DELETE SET NULL 
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabel untuk menyimpan data user PPPoE';

-- =====================================================
-- Table: payments
-- =====================================================
-- Menyimpan data pembayaran dari user
-- =====================================================

CREATE TABLE IF NOT EXISTS payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL COMMENT 'Foreign key ke tabel users',
  amount DECIMAL(10,2) NOT NULL COMMENT 'Jumlah pembayaran',
  payment_date DATE NOT NULL COMMENT 'Tanggal pembayaran',
  payment_month INT NOT NULL COMMENT 'Bulan pembayaran (1-12)',
  payment_year INT NOT NULL COMMENT 'Tahun pembayaran',
  method VARCHAR(50) DEFAULT 'Cash' COMMENT 'Metode pembayaran (Cash, Transfer, dll)',
  note TEXT DEFAULT NULL COMMENT 'Catatan pembayaran',
  created_by VARCHAR(100) DEFAULT NULL COMMENT 'Dibuat oleh (admin/operator)',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_id (user_id),
  INDEX idx_payment_date (payment_date),
  INDEX idx_payment_month_year (payment_month, payment_year),
  INDEX idx_payment_year (payment_year),
  CONSTRAINT fk_payments_users FOREIGN KEY (user_id) 
    REFERENCES users(id) 
    ON DELETE CASCADE 
    ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabel untuk menyimpan data pembayaran user';

-- =====================================================
-- Table: detail_pelanggan (DEPRECATED - for backward compatibility)
-- =====================================================
-- Table ini deprecated, data sekarang ada di table users
-- Tetap dibuat untuk backward compatibility dengan code lama
-- =====================================================

CREATE TABLE IF NOT EXISTS detail_pelanggan (
  id INT AUTO_INCREMENT PRIMARY KEY,
  pppoe_user VARCHAR(100) NOT NULL UNIQUE,
  nomor_hp VARCHAR(20) DEFAULT NULL,
  link_gmaps TEXT DEFAULT NULL,
  foto_path TEXT DEFAULT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_pppoe_user (pppoe_user)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='[DEPRECATED] Tabel detail pelanggan (gunakan table users untuk data baru)';

-- =====================================================
-- Insert Sample Data (Optional - for testing)
-- =====================================================

-- Sample ODP
INSERT INTO odp (name, location, type, splitter_type, maps_link) VALUES
('ODP-01', 'Jl. Merdeka No. 123', 'splitter', '1:8', 'https://maps.google.com/?q=-6.200000,106.816666'),
('ODP-02', 'Jl. Sudirman No. 456', 'ratio', NULL, 'https://maps.google.com/?q=-6.175110,106.865036');

UPDATE odp SET ratio_used = 5, ratio_total = 16 WHERE name = 'ODP-02';

-- Sample Users (comment out if not needed)
-- INSERT INTO users (username, password, profile, wa, odp_id, tanggal_dibuat) VALUES
-- ('user001', 'password123', '10Mbps', '081234567890', 1, NOW()),
-- ('user002', 'password456', '20Mbps', '081234567891', 1, NOW()),
-- ('user003', 'password789', '10Mbps', '081234567892', 2, NOW());

-- Sample Payments (comment out if not needed)
-- INSERT INTO payments (user_id, amount, payment_date, payment_month, payment_year, method, created_by) VALUES
-- (1, 200000, '2024-10-01', 10, 2024, 'Cash', 'admin'),
-- (2, 300000, '2024-10-02', 10, 2024, 'Transfer', 'admin'),
-- (3, 200000, '2024-10-03', 10, 2024, 'Cash', 'admin');

-- =====================================================
-- Useful Queries
-- =====================================================

-- View total pembayaran per bulan
-- SELECT payment_year, payment_month, SUM(amount) as total, COUNT(*) as count 
-- FROM payments 
-- GROUP BY payment_year, payment_month 
-- ORDER BY payment_year DESC, payment_month DESC;

-- View user dengan data pembayaran terakhir
-- SELECT u.username, u.profile, u.wa, 
--        MAX(p.payment_date) as last_payment,
--        COUNT(p.id) as total_payments,
--        SUM(p.amount) as total_amount
-- FROM users u
-- LEFT JOIN payments p ON u.id = p.user_id
-- GROUP BY u.id, u.username, u.profile, u.wa
-- ORDER BY u.username;

-- View ODP dengan jumlah user
-- SELECT o.name, o.location, o.type, 
--        COUNT(u.id) as total_users
-- FROM odp o
-- LEFT JOIN users u ON o.id = u.odp_id
-- GROUP BY o.id, o.name, o.location, o.type
-- ORDER BY o.name;

-- =====================================================
-- Maintenance Queries
-- =====================================================

-- Backup table users
-- CREATE TABLE users_backup AS SELECT * FROM users;

-- Backup table payments
-- CREATE TABLE payments_backup AS SELECT * FROM payments;

-- Reset auto increment (use with caution!)
-- ALTER TABLE payments AUTO_INCREMENT = 1;

-- =====================================================
-- Backup Procedures
-- =====================================================

-- Buat backup users
-- CREATE TABLE users_backup_YYYYMMDD_HHMMSS AS 
-- SELECT *, NOW() as backup_timestamp FROM users;

-- Buat backup payments
-- CREATE TABLE payments_backup_YYYYMMDD_HHMMSS AS 
-- SELECT p.*, u.username, NOW() as backup_timestamp 
-- FROM payments p 
-- LEFT JOIN users u ON p.user_id = u.id;

-- =====================================================
-- End of Schema
-- =====================================================

