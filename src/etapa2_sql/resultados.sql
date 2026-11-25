-- Q1 Resumen por planta (prioridad de revision)
SELECT nombre_estandar, SUM(semaforo='ROJO') rojos, SUM(semaforo='AMARILLO') amarillos, SUM(semaforo='VERDE') verdes,
 ROUND(SUM(ABS(diferencia_l))/1000.0,1) dif_abs_m3, ROUND(AVG(desviacion_pct),2) desv_prom, ROUND(AVG(completitud_pct),2) compl, SUM(dias_cero) ceros
FROM fact_mensual GROUP BY id_planta ORDER BY rojos DESC, amarillos DESC, dif_abs_m3 DESC;
-- Q2 Evolucion mensual
SELECT mes, nombre_mes, ROUND(SUM(vol_total_m3),0) bit_m3, ROUND(SUM(rf_litros)/1000.0,0) rf_m3, ROUND(SUM(rf_original)/1000.0,0) rf_crudo_m3,
 ROUND(SUM(ABS(diferencia_l))/1000.0,1) dif_abs_m3, SUM(semaforo='ROJO') rojos, SUM(semaforo='AMARILLO') amarillos
FROM fact_mensual GROUP BY mes ORDER BY mes;
-- Q3 Totales
SELECT ROUND(SUM(vol_total_m3),0) bit_m3, ROUND(SUM(rf_litros)/1000.0,0) rf_m3, ROUND(SUM(bit_total_reportado_m3),0) bit_rep, ROUND(SUM(vol_riego_m3),0) riego, SUM(dias_con_lectura) dcl, SUM(dias_esperados) de FROM fact_mensual;
SELECT SUM(tiene_riego) FROM dim_planta;
SELECT clave, nombre_estandar, hoja_bitacora, tiene_riego FROM dim_planta;
