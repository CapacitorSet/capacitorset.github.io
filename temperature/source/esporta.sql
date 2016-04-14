DELETE FROM dati WHERE valore = -999; # Dati non validi

# Cambiare il nome del file se necessario su Windows
SELECT * FROM view_dati INTO OUTFILE '/tmp/medie.csv' FIELDS TERMINATED BY ',' ENCLOSED BY '"';