-- MySQL dump for PPPoE Monitor
-- Generated on 2023-11-10 10:00:00
-- Router ID: TEST-ROUTER

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `router_id` varchar(50) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password` varchar(50) NOT NULL,
  `profile` varchar(50) NOT NULL,
  `wa` varchar(20) DEFAULT NULL,
  `maps` varchar(255) DEFAULT NULL,
  `foto` varchar(255) DEFAULT NULL,
  `tanggal_dibuat` datetime DEFAULT NULL,
  `odp_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `router_id`, `username`, `password`, `profile`, `wa`, `maps`, `foto`, `tanggal_dibuat`, `odp_id`, `created_at`, `updated_at`) VALUES
(1, 'TEST-ROUTER', 'user1', 'pass1', 'profile1', '08123456789', 'https://maps.google.com/location1', 'foto1.jpg', '2023-11-10 10:00:00', 1, '2023-11-10 10:00:00', '2023-11-10 10:00:00'),
(2, 'TEST-ROUTER', 'user2', 'pass2', 'profile2', '08123456780', 'https://maps.google.com/location2', 'foto2.jpg', '2023-11-10 10:00:00', 2, '2023-11-10 10:00:00', '2023-11-10 10:00:00');

COMMIT;