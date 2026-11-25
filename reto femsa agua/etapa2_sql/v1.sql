-- V1 Conteos
SELECT (SELECT COUNT(*) FROM dim_planta) plantas, (SELECT COUNT(*) FROM dim_tiempo) dias, (SELECT COUNT(*) FROM fact_volumen_diario) filas_diarias, (SELECT COUNT(*) FROM fact_mensual) planta_mes;
-- V2 tipo de lectura
SELECT tipo_lectura, COUNT(*) FROM fact_volumen_diario GROUP BY 1;
-- V3 Banderas
SELECT SUM(es_cero) ceros, SUM(es_faltante) faltantes, SUM(es_arrastre) arrastres, SUM(es_pico) picos, SUM(es_negativo) negativos FROM fact_volumen_diario;
SELECT p.nombre_estandar, v.fecha, v.vol_efluente_m3, v.mediana_planta_m3 FROM fact_volumen_diario v JOIN dim_planta p USING(id_planta) WHERE es_pico=1;
-- V4 Semaforo
SELECT semaforo, COUNT(*) FROM fact_mensual GROUP BY 1;
SELECT causa_probable, semaforo, COUNT(*) FROM fact_mensual GROUP BY 1,2 ORDER BY 1;
-- V5 Control: el volumen corregido total del periodo = lectura final - inicial
SELECT p.nombre_estandar, SUM(f.vol_descarga_m3) suma, (SELECT lectura_m3 FROM fact_lectura_diaria l WHERE l.id_planta=p.id_planta AND fecha='2026-10-31') - p.lectura_inicial_m3 control FROM fact_mensual f JOIN dim_planta p USING(id_planta) GROUP BY p.id_planta HAVING ABS(suma-control)>0.1;
-- V6 Rojos y amarillos
SELECT nombre_estandar, nombre_mes, bit_total_reportado_m3, vol_total_m3, rf_original, rf_litros, diferencia_l, desviacion_pct, completitud_pct, semaforo, causa_probable FROM fact_mensual WHERE semaforo<>'VERDE' ORDER BY semaforo DESC, desviacion_pct DESC;
