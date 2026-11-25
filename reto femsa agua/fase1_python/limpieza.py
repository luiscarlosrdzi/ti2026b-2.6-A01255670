# =============================================================
# Limpieza de datos: Bitácora de descargas 2026 + Reporting Factory
# =============================================================
# Requisitos (una sola vez, en la terminal):
#   pip install pandas openpyxl
#
# Guarda este archivo DENTRO de la carpeta TrabajoRetoFemsa,
# junto a los dos Excel, y ejecútalo con el botón ▶ de VS Code.
# =============================================================

from pathlib import Path
import pandas as pd

# ---------- 1. Rutas ----------
# Carpeta donde está este script (así no importa desde dónde lo ejecutes)
CARPETA = Path(__file__).parent

ARCHIVO_BITACORA = CARPETA / "Bitacora descargas 2026.xlsx"
ARCHIVO_REPORTING = CARPETA / "ReportingFactory Ene26 - Oct26.xlsx"
ARCHIVO_SALIDA = CARPETA / "datos_limpios.xlsx"

AÑO = 2026


# ---------- 2. Bitácora: de "formato CONAGUA" a tabla diaria ----------
def leer_bitacora(ruta):
    """Convierte cada hoja (planta) en una tabla con una fila por día."""
    # header=None porque el formato no tiene una fila de encabezados normal
    hojas = pd.read_excel(ruta, sheet_name=None, header=None)

    filas = []
    for planta, hoja in hojas.items():
        # Lecturas iniciales al 31-dic del año anterior (celdas H8 y H9)
        lectura_ini_efl = hoja.iat[7, 7]
        lectura_ini_rie = hoja.iat[8, 7]

        # Cada mes ocupa 5 columnas: día | efluente | dif | riego | dif
        for mes in range(1, 13):
            col_efl = 1 + 5 * (mes - 1)    # columna B, G, L, Q...
            col_rie = col_efl + 2          # columna D, I, N, S...

            # Los días van de la fila 16 a la 46 de Excel (índices 15 a 45)
            for i, dia in enumerate(range(1, 32)):
                fecha = pd.to_datetime(f"{AÑO}-{mes:02d}-{dia:02d}", errors="coerce")
                if pd.isna(fecha):         # 30 de febrero, 31 de abril, etc.
                    continue
                filas.append({
                    "planta": planta,
                    "fecha": fecha,
                    "lectura_efluente": hoja.iat[15 + i, col_efl],
                    "lectura_riego": hoja.iat[15 + i, col_rie],
                    "lectura_ini_efl": lectura_ini_efl,
                    "lectura_ini_rie": lectura_ini_rie,
                })

    df = pd.DataFrame(filas)
    # Forzar a número: cualquier texto o celda rara se vuelve vacío (NaN)
    for c in ["lectura_efluente", "lectura_riego", "lectura_ini_efl", "lectura_ini_rie"]:
        df[c] = pd.to_numeric(df[c], errors="coerce")
    return df


def calcular_diferencias(df):
    """Calcula cuánto salió cada día y marca alertas de calidad de datos."""
    resultado = []
    for planta, d in df.groupby("planta"):
        d = d.sort_values("fecha").copy()

        # Solo hasta el último día con lectura (nov-dic están vacíos)
        ultimo = df.loc[df["lectura_efluente"].notna(), "fecha"].max()
        d = d[d["fecha"] <= ultimo]

        for tipo, col_ini in [("efluente", "lectura_ini_efl"), ("riego", "lectura_ini_rie")]:
            lect = d[f"lectura_{tipo}"]
            # Lectura anterior válida (si falta un día, toma la última que sí hay)
            anterior = lect.ffill().shift(1)
            anterior.iloc[0] = d[col_ini].iloc[0]
            # Para días sin lectura, se usa la última válida en el cálculo
            d[f"{'descarga' if tipo == 'efluente' else 'riego'}_m3"] = lect - anterior

        # ----- Alertas -----
        d["falta_lectura"] = d["lectura_efluente"].isna()
        # Día con lectura que viene después de uno o más días vacíos:
        # su diferencia acumula varios días
        d["acumula_dias_previos"] = (~d["falta_lectura"]) & d["falta_lectura"].shift(1, fill_value=False)
        d["diferencia_negativa"] = d["descarga_m3"] < 0
        d["dia_en_cero"] = d["descarga_m3"] == 0

        resultado.append(d)

    out = pd.concat(resultado, ignore_index=True)
    out["mes"] = out["fecha"].dt.month
    return out.drop(columns=["lectura_ini_efl", "lectura_ini_rie"])


def resumen_mensual(diario):
    """Total por planta y mes (equivalente a las celdas DESCARGA / RIEGO / TOTAL MES)."""
    m = (diario.groupby(["planta", "mes"])
               .agg(descarga_m3=("descarga_m3", "sum"),
                    riego_m3=("riego_m3", "sum"),
                    dias_sin_lectura=("falta_lectura", "sum"),
                    dias_en_cero=("dia_en_cero", "sum"))
               .reset_index())
    m["total_mes_m3"] = m["descarga_m3"] + m["riego_m3"]
    return m


# ---------- 3. Reporting Factory ----------
def leer_reporting(ruta):
    hojas = pd.read_excel(ruta, sheet_name=None)
    tablas = []
    for planta, hoja in hojas.items():
        if planta == "TOTAL":          # TOTAL se recalcula después, no se lee
            continue
        hoja = hoja.iloc[:, :4].copy()
        hoja.columns = ["nombre_mes", "mes", "año", "litros_rf"]
        hoja["planta"] = planta
        tablas.append(hoja)
    rf = pd.concat(tablas, ignore_index=True)
    rf["litros_rf"] = pd.to_numeric(rf["litros_rf"], errors="coerce")
    rf["m3_rf"] = rf["litros_rf"] / 1000     # 1 m³ = 1,000 litros
    return rf[["planta", "mes", "nombre_mes", "litros_rf", "m3_rf"]]


# ---------- 4. Conciliación Bitácora vs Reporting Factory ----------
def conciliar(mensual, rf):
    c = rf.merge(mensual, on=["planta", "mes"], how="left")

    def clasificar(r):
        rf_m3, d, t = r["m3_rf"], r["descarga_m3"], r["total_mes_m3"]
        if rf_m3 == d:
            return "OK (igual a descarga)"
        if r["riego_m3"] > 0 and rf_m3 == t:
            return "OK (igual a descarga + riego)"
        if r["litros_rf"] in (d, t):
            return "ERROR: capturado en m3, no en litros"
        if abs(rf_m3 - d) <= 5 or (r["riego_m3"] > 0 and abs(rf_m3 - t) <= 5):
            return "Diferencia menor (<=5 m3)"
        if r["dias_sin_lectura"] > 0:
            return "Revisar: diferencia grande, mes con días sin lectura"
        return "Revisar: diferencia grande sin causa aparente"

    c["diferencia_m3_vs_descarga"] = c["m3_rf"] - c["descarga_m3"]
    c["estatus"] = c.apply(clasificar, axis=1)
    return c


# ---------- 5. Ejecutar ----------
if __name__ == "__main__":
    print("Leyendo bitácora...")
    crudo = leer_bitacora(ARCHIVO_BITACORA)
    diario = calcular_diferencias(crudo)
    mensual = resumen_mensual(diario)

    print("Leyendo Reporting Factory...")
    rf = leer_reporting(ARCHIVO_REPORTING)

    conciliacion = conciliar(mensual, rf)

    # Resumen en pantalla
    print(f"\nPlantas: {diario['planta'].nunique()} | Días: {len(diario):,}")
    print(f"Días sin lectura: {int(diario['falta_lectura'].sum())}")
    print(f"Diferencias negativas: {int(diario['diferencia_negativa'].sum())}")
    print("\nEstatus de la conciliación (planta-mes):")
    print(conciliacion["estatus"].value_counts().to_string())

    # Guardar todo en un Excel nuevo (los originales no se tocan)
    with pd.ExcelWriter(ARCHIVO_SALIDA) as w:
        diario.to_excel(w, sheet_name="Bitacora_diaria", index=False)
        mensual.to_excel(w, sheet_name="Bitacora_mensual", index=False)
        rf.to_excel(w, sheet_name="ReportingFactory", index=False)
        conciliacion.to_excel(w, sheet_name="Conciliacion", index=False)

    print(f"\nListo. Archivo generado: {ARCHIVO_SALIDA.name}")
