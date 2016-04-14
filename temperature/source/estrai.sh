unzip '*.zip'
cat *.csv > dati.csv

# Cambiare i dati di accesso, ed eventualmente --host, come necessario
mysqlimport --local --columns centralina,data,valore --fields-terminated-by=, --user root -p matematica `pwd`/dati.csv

rm *.csv