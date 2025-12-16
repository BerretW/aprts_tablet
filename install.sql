CREATE TABLE IF NOT EXISTS `player_tablets` (
  `serial` varchar(50) NOT NULL,
  `model` varchar(50) DEFAULT 'tablet_basic',
  `tablet_data` longtext DEFAULT NULL,
  PRIMARY KEY (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;