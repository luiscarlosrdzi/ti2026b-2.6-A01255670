-- =====================================================================
-- ETAPA 2 · Exploración de las fuentes en SQL (SQLite)
-- Tablas crudas: raw_bitacora, raw_bitacora_encabezado, raw_bitacora_totales, raw_rf, raw_rf_total
-- =====================================================================
-- E1 Calendario: celdas con dato en días inexistentes y días válidos sin lectura (ene-oct)
WITH cal AS (SELECT hoja, mes, fila-15 AS dia,
  CASE WHEN fila-15 <= CAST(strftime('%d', date(printf('2026-%02d-01',mes),'+1 month','-1 day')) AS INT) THEN 1 ELSE 0 END AS dia_valido,
  lectura_efluente_m3 l, lectura_riego_m3 r FROM raw_bitacora)
SELECT 'dias_validos_ene_oct' k, COUNT(*) v FROM cal WHERE mes<=10 AND dia_valido=1
UNION ALL SELECT 'validos_con_lectura', COUNT(*) FROM cal WHERE mes<=10 AND dia_valido=1 AND l IS NOT NULL
UNION ALL SELECT 'validos_sin_lectura', COUNT(*) FROM cal WHERE mes<=10 AND dia_valido=1 AND l IS NULL
UNION ALL SELECT 'invalidos_con_dato', COUNT(*) FROM cal WHERE dia_valido=0 AND l IS NOT NULL
UNION ALL SELECT 'nov_dic_con_dato', COUNT(*) FROM cal WHERE mes>10 AND l IS NOT NULL
UNION ALL SELECT 'riego_null_vs_flujo', COUNT(*) FROM cal WHERE (l IS NULL) <> (r IS NULL);
-- E2 Dias validos sin lectura por planta-mes
WITH cal AS (SELECT hoja, mes, fila-15 dia, lectura_efluente_m3 l FROM raw_bitacora WHERE mes<=10 AND fila-15 <= CAST(strftime('%d', date(printf('2026-%02d-01',mes),'+1 month','-1 day')) AS INT)) SELECT hoja, mes, group_concat(dia) dias_sin_lectura FROM cal WHERE l IS NULL GROUP BY hoja, mes;
-- E3 Formula del dia 1 de cada mes (referencia a la lectura previa)
SELECT mes, formula_dif, COUNT(*) n_hojas FROM raw_bitacora WHERE fila=16 GROUP BY mes, formula_dif;
-- E4 Formulas de diferencia que no siguen el patron fila-anterior (dias 2-31)
SELECT hoja, mes, fila, celda_flujo, formula_dif FROM raw_bitacora
WHERE fila>16 AND formula_dif IS NOT NULL
 AND formula_dif NOT LIKE '%' || substr(celda_flujo,1,length(celda_flujo)-2) || (fila-1) || '%';
-- E5 Filas sin formula de diferencia en dias validos
SELECT hoja, mes, fila-15 dia FROM raw_bitacora WHERE formula_dif IS NULL AND mes<=10
 AND fila-15 <= CAST(strftime('%d', date(printf('2026-%02d-01',mes),'+1 month','-1 day')) AS INT);
-- E6 Perfil de columnas numericas (ene-oct, dias con lectura)
SELECT 'lectura_efluente_m3' col, COUNT(*) n, MIN(lectura_efluente_m3) mn, MAX(lectura_efluente_m3) mx, ROUND(AVG(lectura_efluente_m3),1) prom FROM raw_bitacora WHERE mes<=10 AND lectura_efluente_m3 IS NOT NULL
UNION ALL SELECT 'dif_efluente_m3', COUNT(dif_efluente_m3), MIN(dif_efluente_m3), MAX(dif_efluente_m3), ROUND(AVG(dif_efluente_m3),1) FROM raw_bitacora WHERE mes<=10
UNION ALL SELECT 'lectura_riego_m3', COUNT(lectura_riego_m3), MIN(lectura_riego_m3), MAX(lectura_riego_m3), ROUND(AVG(lectura_riego_m3),1) FROM raw_bitacora WHERE mes<=10
UNION ALL SELECT 'dif_riego_m3', COUNT(dif_riego_m3), MIN(dif_riego_m3), MAX(dif_riego_m3), ROUND(AVG(dif_riego_m3),1) FROM raw_bitacora WHERE mes<=10;
-- E7 Diferencias diarias negativas (lectura menor a la anterior)
SELECT hoja, mes, fila-15 dia, lectura_efluente_m3, dif_efluente_m3 FROM raw_bitacora WHERE dif_efluente_m3 < 0 ORDER BY hoja, mes, dia;
-- E8 Diferencias diarias en cero (lectura repetida)
SELECT hoja, COUNT(*) n_ceros, group_concat(mes||'/'||(fila-15), ' ') fechas FROM raw_bitacora WHERE dif_efluente_m3 = 0 GROUP BY hoja;
-- E9 Riego negativo o cero vs lectura
SELECT hoja, COUNT(*) n, SUM(dif_riego_m3<0) neg, SUM(dif_riego_m3>0) pos, MIN(dif_riego_m3), MAX(dif_riego_m3), MAX(lectura_riego_m3) FROM raw_bitacora WHERE mes<=10 AND dif_riego_m3 IS NOT NULL GROUP BY hoja HAVING pos>0 OR neg>0;
-- E10 Comparacion bitacora (m3, total cacheado) vs Reporting Factory (litros) por planta-mes
SELECT t.hoja, t.mes, t.descarga_m3, t.riego_m3, r.agua_descarga_ptar rf_litros,
  ROUND(r.agua_descarga_ptar / NULLIF(t.descarga_m3,0),2) factor
FROM raw_bitacora_totales t JOIN raw_rf r ON r.hoja=t.hoja AND r.mes=t.mes
WHERE t.mes<=10 AND ABS(r.agua_descarga_ptar - t.descarga_m3*1000) > 0.5 ORDER BY t.hoja, t.mes;
-- E11 Total cacheado vs suma recalculada de diferencias
SELECT t.hoja, t.mes, t.descarga_m3, SUM(b.dif_efluente_m3) suma FROM raw_bitacora_totales t JOIN raw_bitacora b USING(hoja, mes) GROUP BY t.hoja, t.mes HAVING ABS(IFNULL(t.descarga_m3,0)-IFNULL(SUM(b.dif_efluente_m3),0))>0.01;
-- E12 Nombres de hoja RF vs Bitacora
SELECT (SELECT COUNT(DISTINCT hoja) FROM raw_rf) rf, (SELECT COUNT(DISTINCT hoja) FROM raw_bitacora) bit,
 (SELECT COUNT(*) FROM (SELECT DISTINCT hoja FROM raw_rf) a JOIN (SELECT DISTINCT hoja FROM raw_bitacora) b USING(hoja)) coinciden;
-- E13 Encabezados RF
SELECT encabezado, COUNT(*) FROM raw_rf GROUP BY encabezado;
SELECT DISTINCT nombre_mes, mes, anio FROM raw_rf ORDER BY mes;
-- E14 Comparacion usando TOTAL MES (descarga + riego) en litros
SELECT t.hoja, t.mes, t.descarga_m3, t.riego_m3, t.total_mes_m3, r.agua_descarga_ptar rf, r.agua_descarga_ptar - t.total_mes_m3*1000 dif_l,
 ROUND(100.0*(r.agua_descarga_ptar - t.total_mes_m3*1000)/(t.total_mes_m3*1000),2) pct
FROM raw_bitacora_totales t JOIN raw_rf r ON r.hoja=t.hoja AND r.mes=t.mes
WHERE t.mes<=10 AND ABS(r.agua_descarga_ptar - t.total_mes_m3*1000) > 0.5 ORDER BY t.hoja, t.mes;
SELECT COUNT(*) coinciden_exacto FROM raw_bitacora_totales t JOIN raw_rf r ON r.hoja=t.hoja AND r.mes=t.mes WHERE ABS(r.agua_descarga_ptar - t.total_mes_m3*1000) <= 0.5;
-- E15 Picos: diferencias diarias mayores a 1.8 veces la mediana de la planta (incluye dias de arrastre)
WITH d AS (SELECT hoja, mes, fila-15 dia, dif_efluente_m3 v, formula_dif FROM raw_bitacora WHERE dif_efluente_m3 IS NOT NULL),
r AS (SELECT hoja, v, ROW_NUMBER() OVER (PARTITION BY hoja ORDER BY v) rn, COUNT(*) OVER (PARTITION BY hoja) n FROM d),
med AS (SELECT hoja, AVG(v) mediana FROM r WHERE rn IN ((n+1)/2,(n+2)/2) GROUP BY hoja)
SELECT d.hoja, d.mes, d.dia, d.v, ROUND(m.mediana,1) mediana, ROUND(d.v/m.mediana,2) veces FROM d JOIN med m USING(hoja)
WHERE d.v > 1.8*m.mediana ORDER BY veces DESC;
-- E16 Mediana diaria vs flujo nominal del encabezado
WITH d AS (SELECT hoja, dif_efluente_m3 v FROM raw_bitacora WHERE dif_efluente_m3 IS NOT NULL),
r AS (SELECT hoja, v, ROW_NUMBER() OVER (PARTITION BY hoja ORDER BY v) rn, COUNT(*) OVER (PARTITION BY hoja) n FROM d)
SELECT r.hoja, AVG(v) mediana, e.flujo_promedio_m3_dia, e.leyenda_corte FROM r JOIN raw_bitacora_encabezado e USING(hoja) WHERE rn IN ((n+1)/2,(n+2)/2) GROUP BY r.hoja;
-- E17 Picos por regla IQR (Q3 + 3*IQR) por planta, excluyendo dia de arrastre
WITH d AS (SELECT b.hoja, b.mes, b.fila-15 dia, b.dif_efluente_m3 v FROM raw_bitacora b WHERE dif_efluente_m3 IS NOT NULL
   AND NOT (fila=16 AND formula_dif NOT LIKE '%46=%' AND formula_dif NOT LIKE '%45=%' AND formula_dif NOT LIKE '%43=%' AND formula_dif NOT LIKE '%H8=%')),
r AS (SELECT hoja, v, ROW_NUMBER() OVER (PARTITION BY hoja ORDER BY v) rn, COUNT(*) OVER (PARTITION BY hoja) n FROM d),
q AS (SELECT hoja, MAX(CASE WHEN rn=CAST(n*0.25 AS INT) THEN v END) q1, MAX(CASE WHEN rn=CAST(n*0.75 AS INT) THEN v END) q3 FROM r GROUP BY hoja)
SELECT d.hoja, d.mes, d.dia, d.v, q.q1, q.q3, q.q3+3*(q.q3-q.q1) lim_sup, q.q1-3*(q.q3-q.q1) lim_inf FROM d JOIN q USING(hoja)
WHERE d.v > q.q3+3*(q.q3-q.q1) OR (d.v < q.q1-3*(q.q3-q.q1));
-- E18 Dias consecutivos con lectura repetida (2+ ceros seguidos)
SELECT hoja, mes, fila-15 dia FROM raw_bitacora a WHERE dif_efluente_m3=0 AND EXISTS (SELECT 1 FROM raw_bitacora b WHERE b.hoja=a.hoja AND b.mes=a.mes AND b.fila=a.fila-1 AND b.dif_efluente_m3=0);
-- E19 Dia siguiente a una diferencia en cero
SELECT a.hoja, a.mes, a.fila-15 dia, a.dif_efluente_m3 cero, b.dif_efluente_m3 siguiente, c.dif_efluente_m3 anterior FROM raw_bitacora a
LEFT JOIN raw_bitacora b ON b.hoja=a.hoja AND b.mes=a.mes AND b.fila=a.fila+1
LEFT JOIN raw_bitacora c ON c.hoja=a.hoja AND c.mes=a.mes AND c.fila=a.fila-1
WHERE a.dif_efluente_m3=0 LIMIT 25;
