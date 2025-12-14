-- 1. Buat Tabel system_logs
CREATE TABLE IF NOT EXISTS `system_logs` (
  `id` int(255) NOT NULL AUTO_INCREMENT,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `username` varchar(255) NOT NULL,
  `action` varchar(255) NOT NULL,
  `details` text,
  `ip_address` varchar(255),
  `router_id` varchar(255),
  PRIMARY KEY (`id`),
  KEY `idx_router_created_at` (`router_id`, `created_at`),
  KEY `idx_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
