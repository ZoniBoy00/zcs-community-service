CREATE TABLE IF NOT EXISTS `community_service` (
    `identifier` varchar(60) NOT NULL,
    `spots_assigned` int(11) NOT NULL,
    `spots_remaining` int(11) NOT NULL,
    PRIMARY KEY (`identifier`)
);

CREATE TABLE IF NOT EXISTS `community_service_inventory` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `identifier` varchar(60) NOT NULL,
    `items` longtext,
    `storage_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
);

