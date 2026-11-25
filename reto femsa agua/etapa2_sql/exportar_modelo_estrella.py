"""Exporta el esquema en estrella (femsa.db) a un Excel para conectar Power BI."""
import sqlite3
import pandas as pd
from pathlib import Path

CARPETA = Path(__file__).parent
con = sqlite3.connect(CARPETA / "femsa.db")

tablas = ["dim_planta", "dim_tiempo_mes", "dim_diagnostico", "fact_conciliacion_mensual"]
salida = CARPETA.parent.parent / "modelo_estrella_powerbi.xlsx"

with pd.ExcelWriter(salida) as writer:
    for t in tablas:
        df = pd.read_sql(f"SELECT * FROM {t}", con)
        df.to_excel(writer, sheet_name=t, index=False)
        print(f"{t}: {len(df)} filas, {len(df.columns)} columnas")

print(f"\nListo: {salida}")
