CREATE TABLE IF NOT EXISTS `community_service` (
    `citizenid` varchar(50) NOT NULL,
    `spots_assigned` int(11) NOT NULL,
    `spots_remaining` int(11) NOT NULL,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `community_service_inventory` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `citizenid` varchar(50) NOT NULL,
    `items` longtext DEFAULT NULL,
    `storage_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
