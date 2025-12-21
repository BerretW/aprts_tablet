CREATE TABLE IF NOT EXISTS `player_tablets` (
  `serial` varchar(50) NOT NULL,
  `model` varchar(50) DEFAULT 'tablet_basic',
  `tablet_data` longtext DEFAULT NULL,
  PRIMARY KEY (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `player_tablets` (
  `serial` varchar(50) NOT NULL,
  `model` varchar(50) DEFAULT 'tablet_basic',
  `battery` int(11) DEFAULT 100,
  `tablet_data` longtext DEFAULT NULL,
  PRIMARY KEY (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Tuhle tabulku jsi tam neměl:
CREATE TABLE IF NOT EXISTS `player_tablets_calendar` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `serial` varchar(50) NOT NULL,
  `event_date` varchar(50) NOT NULL,
  `event_time` varchar(20) NOT NULL,
  `title` varchar(255) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `serial_index` (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- A tuhle pro routery taky ne:
CREATE TABLE IF NOT EXISTS `placed_routers` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `coords` longtext NOT NULL, -- Ukládáš JSON
  `ssid` varchar(50) NOT NULL,
  `password` varchar(50) DEFAULT NULL,
  `type` varchar(50) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;