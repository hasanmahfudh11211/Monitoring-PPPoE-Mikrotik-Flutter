-- =====================================================
-- Migration: Add PPP Profile Pricing Table
-- =====================================================
-- Version: 2.0
-- Created: 2024
-- Description: Menambahkan tabel untuk menyimpan harga per PPP Profile
-- =====================================================

USE pppoe_monitor;

-- =====================================================
-- Table: ppp_profile_pricing
-- =====================================================
-- Menyimpan harga untuk setiap PPP Profile
-- =====================================================

CREATE TABLE IF NOT EXISTS ppp_profile_pricing (
  id INT AUTO_INCREMENT PRIMARY KEY,
  router_id VARCHAR(255) NOT NULL COMMENT 'Router ID untuk multi-router support',
  profile_name VARCHAR(100) NOT NULL COMMENT 'Nama profile PPP dari Mikrotik',
  price DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'Harga per bulan dalam Rupiah',
  description TEXT DEFAULT NULL COMMENT 'Deskripsi atau catatan tambahan',
  is_active TINYINT(1) DEFAULT 1 COMMENT 'Status aktif (1=aktif, 0=nonaktif)',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY unique_profile_router (router_id, profile_name),
  INDEX idx_router_id (router_id),
  INDEX idx_profile_name (profile_name),
  INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabel untuk menyimpan harga per PPP Profile';

-- =====================================================
-- Sample Data (Optional - comment out if not needed)
-- =====================================================

-- INSERT INTO ppp_profile_pricing (router_id, profile_name, price, description) VALUES
-- ('default', '10Mbps', 150000, 'Paket 10 Mbps'),
-- ('default', '20Mbps', 200000, 'Paket 20 Mbps'),
-- ('default', '50Mbps', 300000, 'Paket 50 Mbps');

-- =====================================================
-- Useful Queries
-- =====================================================

-- View semua profile dengan harga
-- SELECT p.name as profile_name, pr.price, pr.description, pr.is_active
-- FROM ppp_profile_pricing pr
-- LEFT JOIN (SELECT DISTINCT profile FROM users WHERE router_id = ?) p ON pr.profile_name = p.profile
-- WHERE pr.router_id = ? AND pr.is_active = 1
-- ORDER BY pr.price ASC;

-- =====================================================
-- End of Migration
-- =====================================================


