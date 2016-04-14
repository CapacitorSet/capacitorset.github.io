# Importare a mano il file CSV nella variabile temperatura

dati <- split(temperatura, f = temperatura$V1)

boxplot(V3 ~ V2, data = dati$Pastori)

# Salvare a mano il grafico

boxplot(V3 ~ V2, data = dati$Ziziola)

# Salvare a mano il grafico