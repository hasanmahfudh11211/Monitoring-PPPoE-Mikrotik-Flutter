CREATE TABLE IF NOT EXISTS `download_logs` (
  `id` int(255) NOT NULL AUTO_INCREMENT,
  `download_time` datetime DEFAULT CURRENT_TIMESTAMP,
  `ip_address` varchar(255) DEFAULT NULL,
  `user_agent` text,
  `version` varchar(255) DEFAULT NULL,
  `status` varchar(255) DEFAULT 'success',
  PRIMARY KEY (`id`),
  KEY `idx_download_time` (`download_time`),
  KEY `idx_version` (`version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
