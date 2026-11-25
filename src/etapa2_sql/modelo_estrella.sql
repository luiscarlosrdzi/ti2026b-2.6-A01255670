-- =====================================================================
-- Etapa 4 · Materializa el esquema en estrella documentado en Etapa 3
-- Parte de dim_planta, dim_tiempo y fact_mensual (ya existentes) y crea:
--   dim_tiempo_mes      (grano mes, para relacionar con el hecho mensual)
--   dim_diagnostico     (dimension basura: semaforo + causa + banderas)
--   fact_conciliacion_mensual  (hecho limpio, solo llaves + metricas)
-- No modifica las tablas originales.
-- =====================================================================

DROP TABLE IF EXISTS dim_tiempo_mes;
CREATE TABLE dim_tiempo_mes AS
SELECT DISTINCT mes, nombre_mes, anio, trimestre, dias_mes
FROM dim_tiempo
WHERE mes <= 10
ORDER BY mes;

DROP TABLE IF EXISTS dim_diagnostico;
CREATE TABLE dim_diagnostico (
  id_diagnostico INTEGER PRIMARY KEY AUTOINCREMENT,
  semaforo TEXT NOT NULL,
  causa_probable TEXT NOT NULL,
  error_unidad INTEGER NOT NULL,
  rf_omite_riego INTEGER NOT NULL,
  coincide_crudo INTEGER NOT NULL
);
INSERT INTO dim_diagnostico (semaforo, causa_probable, error_unidad, rf_omite_riego, coincide_crudo)
SELECT DISTINCT semaforo, causa_probable, error_unidad, rf_omite_riego, coincide_crudo
FROM fact_mensual
ORDER BY semaforo, causa_probable;

DROP TABLE IF EXISTS fact_conciliacion_mensual;
CREATE TABLE fact_conciliacion_mensual AS
SELECT
  f.id_planta,
  f.mes,
  d.id_diagnostico,
  f.dias_esperados, f.dias_con_lectura, f.dias_faltantes, f.dias_estimados,
  f.dias_cero, f.dias_pico, f.dias_arrastre, f.dias_negativos,
  f.bit_descarga_reportada_m3, f.bit_riego_reportado_m3, f.bit_total_reportado_m3,
  f.vol_descarga_m3, f.vol_riego_m3, f.vol_total_m3, f.vol_total_l,
  f.rf_original, f.rf_litros,
  f.diferencia_l, f.desviacion_pct, f.tasa_atipicas_pct, f.completitud_pct
FROM fact_mensual f
JOIN dim_diagnostico d
  ON d.semaforo = f.semaforo AND d.causa_probable = f.causa_probable
 AND d.error_unidad = f.error_unidad AND d.rf_omite_riego = f.rf_omite_riego
 AND d.coincide_crudo = f.coincide_crudo;

-- Controles
SELECT 'dim_planta' t, COUNT(*) n FROM dim_planta
UNION ALL SELECT 'dim_tiempo_mes', COUNT(*) FROM dim_tiempo_mes
UNION ALL SELECT 'dim_diagnostico', COUNT(*) FROM dim_diagnostico
UNION ALL SELECT 'fact_conciliacion_mensual', COUNT(*) FROM fact_conciliacion_mensual
UNION ALL SELECT 'fact_mensual (original)', COUNT(*) FROM fact_mensual;
