-- =====================================================================
-- ETAPA 2 · Limpieza, estandarización y nuevos atributos (SQLite)
-- Los datos crudos (raw_*) nunca se modifican; todo se deriva en tablas nuevas.
-- =====================================================================

-- R1. Catálogo maestro de plantas: clave única y nombre estándar
DROP TABLE IF EXISTS dim_planta;
CREATE TABLE dim_planta(id_planta INTEGER PRIMARY KEY, clave TEXT UNIQUE, nombre_estandar TEXT,
  hoja_bitacora TEXT, hoja_rf TEXT, lectura_inicial_m3 REAL, lectura_inicial_riego_m3 REAL,
  flujo_nominal_m3_dia REAL, tiene_riego INTEGER);
INSERT INTO dim_planta(clave, nombre_estandar, hoja_bitacora, hoja_rf, lectura_inicial_m3, lectura_inicial_riego_m3, flujo_nominal_m3_dia, tiene_riego)
SELECT
  UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(e.hoja,'á','A'),'é','E'),'í','I'),'ó','O'),'ú','U'),'Cd. ','CIUDAD'),' ',''),'.','')) AS clave,
  CASE e.hoja WHEN 'Cd. Victoria' THEN 'Ciudad Victoria' WHEN 'PozaRica' THEN 'Poza Rica'
              WHEN 'SanCristobal' THEN 'San Cristóbal' WHEN 'SanJuanDelRio' THEN 'San Juan del Río'
              ELSE e.hoja END,
  e.hoja, r.hoja, e.lectura_inicial_efluente_m3, e.lectura_inicial_riego_m3, e.flujo_promedio_m3_dia,
  CASE WHEN (SELECT MAX(lectura_riego_m3) FROM raw_bitacora b WHERE b.hoja=e.hoja) > 0 THEN 1 ELSE 0 END
FROM raw_bitacora_encabezado e LEFT JOIN (SELECT DISTINCT hoja FROM raw_rf) r ON r.hoja = e.hoja
ORDER BY e.hoja;

-- R2. Dimensión de tiempo (calendario real ene-oct 2026)
DROP TABLE IF EXISTS dim_tiempo;
CREATE TABLE dim_tiempo AS
WITH RECURSIVE d(fecha) AS (SELECT '2026-01-01' UNION ALL SELECT date(fecha,'+1 day') FROM d WHERE fecha < '2026-10-31')
SELECT fecha, CAST(strftime('%Y',fecha) AS INT) anio, CAST(strftime('%m',fecha) AS INT) mes,
  CAST(strftime('%d',fecha) AS INT) dia,
  CASE CAST(strftime('%m',fecha) AS INT) WHEN 1 THEN 'Enero' WHEN 2 THEN 'Febrero' WHEN 3 THEN 'Marzo' WHEN 4 THEN 'Abril'
   WHEN 5 THEN 'Mayo' WHEN 6 THEN 'Junio' WHEN 7 THEN 'Julio' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Septiembre' ELSE 'Octubre' END nombre_mes,
  CAST(strftime('%d', date(fecha,'start of month','+1 month','-1 day')) AS INT) dias_mes,
  (CAST(strftime('%m',fecha) AS INT)+2)/3 trimestre,
  CAST(strftime('%w',fecha) AS INT) dia_semana
FROM d;

-- R3. Lecturas diarias en formato largo (una fila por planta-día) con fecha real
DROP TABLE IF EXISTS stg_lectura;
CREATE TABLE stg_lectura AS
SELECT p.id_planta, t.fecha, t.mes, t.dia, b.lectura_efluente_m3 lectura_m3, b.lectura_riego_m3 lectura_riego_m3,
  b.dif_efluente_m3 dif_original_m3, b.celda_flujo celda_origen
FROM dim_planta p CROSS JOIN dim_tiempo t
LEFT JOIN raw_bitacora b ON b.hoja = p.hoja_bitacora AND b.mes = t.mes AND b.fila - 15 = t.dia;

-- R4. Lectura anterior y siguiente conocidas (para interpolar huecos)
DROP TABLE IF EXISTS stg_lectura_ctx;
CREATE TABLE stg_lectura_ctx AS
SELECT s.*,
  COALESCE((SELECT x.fecha FROM stg_lectura x WHERE x.id_planta=s.id_planta AND x.fecha<s.fecha AND x.lectura_m3 IS NOT NULL ORDER BY x.fecha DESC LIMIT 1),'2025-12-31') f_ant,
  COALESCE((SELECT x.lectura_m3 FROM stg_lectura x WHERE x.id_planta=s.id_planta AND x.fecha<s.fecha AND x.lectura_m3 IS NOT NULL ORDER BY x.fecha DESC LIMIT 1),
           (SELECT lectura_inicial_m3 FROM dim_planta p WHERE p.id_planta=s.id_planta)) l_ant,
  COALESCE((SELECT x.lectura_riego_m3 FROM stg_lectura x WHERE x.id_planta=s.id_planta AND x.fecha<s.fecha AND x.lectura_m3 IS NOT NULL ORDER BY x.fecha DESC LIMIT 1),
           (SELECT lectura_inicial_riego_m3 FROM dim_planta p WHERE p.id_planta=s.id_planta)) r_ant,
  (SELECT x.fecha FROM stg_lectura x WHERE x.id_planta=s.id_planta AND x.fecha>s.fecha AND x.lectura_m3 IS NOT NULL ORDER BY x.fecha LIMIT 1) f_sig,
  (SELECT x.lectura_m3 FROM stg_lectura x WHERE x.id_planta=s.id_planta AND x.fecha>s.fecha AND x.lectura_m3 IS NOT NULL ORDER BY x.fecha LIMIT 1) l_sig,
  (SELECT x.lectura_riego_m3 FROM stg_lectura x WHERE x.id_planta=s.id_planta AND x.fecha>s.fecha AND x.lectura_m3 IS NOT NULL ORDER BY x.fecha LIMIT 1) r_sig
FROM stg_lectura s;

-- R5. Promedio diario del mes (para huecos al cierre del periodo sin lectura posterior)
DROP TABLE IF EXISTS stg_prom_mes;
CREATE TABLE stg_prom_mes AS
SELECT id_planta, mes, AVG(dif_original_m3) prom_dif_m3 FROM stg_lectura
WHERE lectura_m3 IS NOT NULL AND dia > 1 GROUP BY id_planta, mes;

-- R6. Lectura corregida: real, interpolada linealmente o estimada por promedio
DROP TABLE IF EXISTS fact_lectura_diaria;
CREATE TABLE fact_lectura_diaria AS
SELECT c.id_planta, c.fecha, c.mes, c.dia, c.celda_origen,
  c.lectura_m3 lectura_original_m3,
  CASE WHEN c.lectura_m3 IS NOT NULL THEN c.lectura_m3
       WHEN c.l_sig IS NOT NULL THEN ROUND(c.l_ant + (c.l_sig-c.l_ant) * (julianday(c.fecha)-julianday(c.f_ant)) / (julianday(c.f_sig)-julianday(c.f_ant)), 2)
       ELSE ROUND(c.l_ant + pm.prom_dif_m3 * (julianday(c.fecha)-julianday(c.f_ant)), 2) END lectura_m3,
  CASE WHEN c.lectura_m3 IS NOT NULL THEN c.lectura_riego_m3
       WHEN c.r_sig IS NOT NULL THEN ROUND(c.r_ant + (c.r_sig-c.r_ant) * (julianday(c.fecha)-julianday(c.f_ant)) / (julianday(c.f_sig)-julianday(c.f_ant)), 2)
       ELSE c.r_ant END lectura_riego_m3,
  CASE WHEN c.lectura_m3 IS NOT NULL THEN 'REAL' WHEN c.l_sig IS NOT NULL THEN 'INTERPOLADA' ELSE 'ESTIMADA' END tipo_lectura,
  c.dif_original_m3
FROM stg_lectura_ctx c LEFT JOIN stg_prom_mes pm ON pm.id_planta=c.id_planta AND pm.mes=c.mes;

-- R7. Volumen diario corregido y banderas de calidad
DROP TABLE IF EXISTS fact_volumen_diario;
CREATE TABLE fact_volumen_diario AS
WITH v AS (
 SELECT f.*,
   f.lectura_m3 - COALESCE(LAG(f.lectura_m3) OVER w, p.lectura_inicial_m3) vol_efluente_m3,
   f.lectura_riego_m3 - COALESCE(LAG(f.lectura_riego_m3) OVER w, p.lectura_inicial_riego_m3) vol_riego_m3,
   LAG(f.tipo_lectura) OVER w tipo_ant
 FROM fact_lectura_diaria f JOIN dim_planta p USING(id_planta)
 WINDOW w AS (PARTITION BY f.id_planta ORDER BY f.fecha)),
q AS (SELECT id_planta, vol_efluente_m3 x, ROW_NUMBER() OVER (PARTITION BY id_planta ORDER BY vol_efluente_m3) rn,
        COUNT(*) OVER (PARTITION BY id_planta) n FROM v WHERE tipo_lectura='REAL' AND vol_efluente_m3 > 0),
iqr AS (SELECT id_planta, MAX(CASE WHEN rn=CAST(n*0.25 AS INT) THEN x END) q1, MAX(CASE WHEN rn=CAST(n*0.75 AS INT) THEN x END) q3,
        MAX(CASE WHEN rn=CAST(n*0.50 AS INT) THEN x END) mediana FROM q GROUP BY id_planta)
SELECT v.id_planta, v.fecha, v.mes, v.dia, v.celda_origen, v.lectura_original_m3, v.lectura_m3, v.lectura_riego_m3, v.tipo_lectura,
  v.dif_original_m3, ROUND(v.vol_efluente_m3,2) vol_efluente_m3, ROUND(v.vol_riego_m3,2) vol_riego_m3,
  ROUND(v.vol_efluente_m3 + v.vol_riego_m3,2) vol_total_m3, ROUND((v.vol_efluente_m3 + v.vol_riego_m3)*1000,0) vol_total_l,
  CASE WHEN v.tipo_lectura='REAL' AND v.dif_original_m3 = 0 THEN 1 ELSE 0 END es_cero,
  CASE WHEN v.tipo_lectura<>'REAL' THEN 1 ELSE 0 END es_faltante,
  CASE WHEN v.tipo_lectura='REAL' AND v.tipo_ant IN ('INTERPOLADA','ESTIMADA') THEN 1 ELSE 0 END es_arrastre,
  CASE WHEN v.tipo_lectura='REAL' AND COALESCE(v.tipo_ant,'REAL')='REAL' AND v.vol_efluente_m3 > i.q3 + 3*(i.q3-i.q1) THEN 1 ELSE 0 END es_pico,
  CASE WHEN v.vol_efluente_m3 < 0 THEN 1 ELSE 0 END es_negativo,
  i.mediana mediana_planta_m3
FROM v JOIN iqr i USING(id_planta);

-- R8. Reporting Factory estandarizado: litros, clave de planta y corrección de unidad
DROP TABLE IF EXISTS stg_rf;
CREATE TABLE stg_rf AS
SELECT p.id_planta, r.anio, r.mes, r.agua_descarga_ptar rf_original,
  CASE WHEN r.agua_descarga_ptar < 100000 AND b.vol_m3 > 0 AND ABS(r.agua_descarga_ptar - b.vol_m3)/b.vol_m3 < 0.2 THEN 1 ELSE 0 END error_unidad
FROM raw_rf r JOIN dim_planta p ON p.hoja_rf = r.hoja
JOIN (SELECT hoja, mes, total_mes_m3 vol_m3 FROM raw_bitacora_totales) b ON b.hoja = r.hoja AND b.mes = r.mes;
ALTER TABLE stg_rf ADD COLUMN rf_litros REAL;
UPDATE stg_rf SET rf_litros = CASE WHEN error_unidad=1 THEN rf_original*1000 ELSE rf_original END;

-- R9. Hecho mensual planta-mes: métricas, KPIs y semáforo
DROP TABLE IF EXISTS fact_mensual;
CREATE TABLE fact_mensual AS
WITH m AS (
 SELECT id_planta, mes,
  COUNT(*) dias_esperados, SUM(tipo_lectura='REAL') dias_con_lectura, SUM(es_faltante) dias_faltantes,
  SUM(es_cero) dias_cero, SUM(es_pico) dias_pico, SUM(es_arrastre) dias_arrastre, SUM(es_negativo) dias_negativos,
  ROUND(SUM(vol_efluente_m3),2) vol_descarga_m3, ROUND(SUM(vol_riego_m3),2) vol_riego_m3, ROUND(SUM(vol_total_m3),2) vol_total_m3,
  SUM(tipo_lectura='ESTIMADA') dias_estimados
 FROM fact_volumen_diario GROUP BY id_planta, mes)
SELECT p.id_planta, p.clave, p.nombre_estandar, m.mes, t.nombre_mes,
  m.dias_esperados, m.dias_con_lectura, m.dias_faltantes, m.dias_estimados, m.dias_cero, m.dias_pico, m.dias_arrastre, m.dias_negativos,
  bt.descarga_m3 bit_descarga_reportada_m3, bt.riego_m3 bit_riego_reportado_m3, bt.total_mes_m3 bit_total_reportado_m3,
  m.vol_descarga_m3, m.vol_riego_m3, m.vol_total_m3, m.vol_total_m3*1000 vol_total_l,
  r.rf_original, r.error_unidad, r.rf_litros,
  ROUND(m.vol_total_m3*1000 - r.rf_litros,0) diferencia_l,
  ROUND(100.0*ABS(m.vol_total_m3*1000 - r.rf_litros)/NULLIF(r.rf_litros,0),2) desviacion_pct,
  ROUND(100.0*(m.dias_cero+m.dias_pico+m.dias_negativos)/m.dias_esperados,2) tasa_atipicas_pct,
  ROUND(100.0*m.dias_con_lectura/m.dias_esperados,2) completitud_pct,
  CASE WHEN ABS(bt.total_mes_m3*1000 - r.rf_original) <= 500 THEN 1 ELSE 0 END coincide_crudo,
  CASE WHEN r.error_unidad=0 AND ABS(bt.descarga_m3*1000 - r.rf_litros) <= 500 AND bt.riego_m3 > 0 THEN 1 ELSE 0 END rf_omite_riego
FROM m JOIN dim_planta p USING(id_planta)
JOIN (SELECT DISTINCT mes, nombre_mes FROM dim_tiempo) t USING(mes)
JOIN raw_bitacora_totales bt ON bt.hoja = p.hoja_bitacora AND bt.mes = m.mes
JOIN stg_rf r ON r.id_planta = m.id_planta AND r.mes = m.mes;

ALTER TABLE fact_mensual ADD COLUMN semaforo TEXT;
ALTER TABLE fact_mensual ADD COLUMN causa_probable TEXT;
UPDATE fact_mensual SET semaforo = CASE
   WHEN error_unidad = 1 OR desviacion_pct > 5 THEN 'ROJO'
   WHEN desviacion_pct > 1 AND ABS(diferencia_l) > 5000 THEN 'AMARILLO'
   WHEN completitud_pct < 100 OR rf_omite_riego = 1 THEN 'AMARILLO'
   ELSE 'VERDE' END;
UPDATE fact_mensual SET causa_probable = CASE
   WHEN error_unidad = 1 THEN 'RF capturado en m3 en lugar de litros'
   WHEN rf_omite_riego = 1 THEN 'RF omite el volumen de riego'
   WHEN dias_estimados > 0 THEN 'Cierre de mes sin lectura (volumen estimado)'
   WHEN dias_faltantes > 0 OR dias_arrastre > 0 THEN 'Días sin lectura / arrastre entre meses'
   WHEN desviacion_pct > 1 AND ABS(diferencia_l) > 5000 THEN 'Diferencia sin causa en bitácora (revisar captura RF)'
   WHEN ABS(diferencia_l) > 0 THEN 'Redondeo menor (≤ 5 m3)'
   ELSE 'Sin diferencia' END;
