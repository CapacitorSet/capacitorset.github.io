CREATE TABLE `centraline` (
  `ID` int(11) NOT NULL,
  `nome` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE TABLE `dati` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `centralina` int(11) DEFAULT NULL,
  `data` datetime DEFAULT NULL,
  `valore` float DEFAULT NULL,
  PRIMARY KEY (`ID`),
  KEY `centralina` (`centralina`),
  CONSTRAINT `dati_ibfk_1` FOREIGN KEY (`centralina`) REFERENCES `centraline` (`ID`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1780741 DEFAULT CHARSET=latin1;

CREATE VIEW `dati_v` AS select `centraline`.`nome` AS `nome`,`dati`.`data` AS `data`,`dati`.`valore` AS `valore` from (`dati` join `centraline` on((`centraline`.`ID` = `dati`.`centralina`)));
CREATE VIEW `medie_stagionali_v` AS select `dati_v`.`nome` AS `nome`,month(`dati_v`.`data`) AS `mese`,round(avg(`dati_v`.`valore`),2) AS `media` from `dati_v` where (`dati_v`.`valore` <> -(999)) group by month(`dati_v`.`data`),`dati_v`.`nome` order by `dati_v`.`nome`,month(`dati_v`.`data`);
CREATE VIEW `view_dati` AS select `dati_v`.`nome` AS `nome`,if((month(`dati_v`.`data`) = 12),(year(`dati_v`.`data`) + 1),year(`dati_v`.`data`)) AS `anno`,`dati_v`.`valore` AS `valore` from `dati_v` where (((month(`dati_v`.`data`) = 12) and (dayofmonth(`dati_v`.`data`) >= 22)) or (month(`dati_v`.`data`) = 1) or (month(`dati_v`.`data`) = 2) or ((month(`dati_v`.`data`) = 3) and (dayofmonth(`dati_v`.`data`) <= 20)));