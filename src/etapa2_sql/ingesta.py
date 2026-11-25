"""Ingesta de fuentes crudas a SQLite (sin modificar los valores originales)."""
import openpyxl, sqlite3, sys, unicodedata
from openpyxl.utils import get_column_letter as L
bit, rf, db = sys.argv[1:4]
con = sqlite3.connect(db); cur = con.cursor()
cur.executescript("""
DROP TABLE IF EXISTS raw_bitacora; DROP TABLE IF EXISTS raw_bitacora_encabezado;
DROP TABLE IF EXISTS raw_bitacora_totales; DROP TABLE IF EXISTS raw_rf; DROP TABLE IF EXISTS raw_rf_total;
CREATE TABLE raw_bitacora(hoja TEXT, mes INTEGER, fila INTEGER, dia_celda INTEGER,
  celda_flujo TEXT, lectura_efluente_m3 REAL, formula_dif TEXT, dif_efluente_m3 REAL,
  lectura_riego_m3 REAL, dif_riego_m3 REAL);
CREATE TABLE raw_bitacora_encabezado(hoja TEXT, leyenda_corte TEXT, lectura_inicial_efluente_m3 REAL,
  flujo_promedio_m3_dia REAL, unidad TEXT, lectura_inicial_riego_m3 REAL);
CREATE TABLE raw_bitacora_totales(hoja TEXT, mes INTEGER, descarga_m3 REAL, riego_m3 REAL, total_mes_m3 REAL,
  max_lectura REAL, prom_lectura REAL, min_lectura REAL, max_dif REAL, prom_dif REAL, min_dif REAL);
CREATE TABLE raw_rf(hoja TEXT, nombre_mes TEXT, mes INTEGER, anio INTEGER, agua_descarga_ptar REAL, encabezado TEXT);
CREATE TABLE raw_rf_total(nombre_mes TEXT, mes INTEGER, anio INTEGER, formula TEXT);
""")
wb = openpyxl.load_workbook(bit); wbv = openpyxl.load_workbook(bit, data_only=True)
for ws in wb.worksheets:
    v = wbv[ws.title]
    cur.execute("INSERT INTO raw_bitacora_encabezado VALUES(?,?,?,?,?,?)",
        (ws.title, ws['C8'].value, ws['H8'].value, ws['J8'].value, ws['K8'].value, ws['H9'].value))
    for m in range(12):
        s = 2 + 5*m
        for r in range(16, 47):
            cur.execute("INSERT INTO raw_bitacora VALUES(?,?,?,?,?,?,?,?,?,?)",
                (ws.title, m+1, r, ws.cell(r, s-1).value, f"{L(s)}{r}", ws.cell(r, s).value,
                 ws.cell(r, s+1).value, v.cell(r, s+1).value if v.cell(r, s+1).value != '' else None,
                 ws.cell(r, s+2).value, v.cell(r, s+3).value if v.cell(r, s+3).value != '' else None))
        g = lambda rr, cc: v.cell(rr, cc).value
        cur.execute("INSERT INTO raw_bitacora_totales VALUES(?,?,?,?,?,?,?,?,?,?,?)",
            (ws.title, m+1, g(52, s+1), g(52, s+3), g(53, s+3), g(48, s), g(49, s), g(50, s), g(48, s+1), g(49, s+1), g(50, s+1)))
wb = openpyxl.load_workbook(rf)
for ws in wb.worksheets:
    hdr = ws['D1'].value
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[0] is None: continue
        if ws.title == 'TOTAL':
            cur.execute("INSERT INTO raw_rf_total VALUES(?,?,?,?)", row[:4])
        else:
            cur.execute("INSERT INTO raw_rf VALUES(?,?,?,?,?,?)", (ws.title, *row[:4], hdr))
con.commit()
for t in ['raw_bitacora','raw_bitacora_encabezado','raw_bitacora_totales','raw_rf','raw_rf_total']:
    print(t, cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0])
