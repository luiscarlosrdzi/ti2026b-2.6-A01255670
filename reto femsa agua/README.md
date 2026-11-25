# Reto FEMSA Agua

Auditoría Interna de FEMSA (KOF) necesita validar, con trazabilidad y enfoque de riesgo, si la descarga de agua que reporta cada planta coincide con lo registrado en **Reporting Factory** (la plataforma corporativa), y convertir esa validación en un **semáforo de cumplimiento por planta y periodo**. Alcance del MVP: las 23 plantas de México, enero-octubre 2026.

Esta carpeta concentra todo el trabajo del reto, en el orden en que se construyó.

## Contenido

| Carpeta | Qué es | Estado |
| --- | --- | --- |
| [`etapa2_sql/`](etapa2_sql) | Limpieza en SQL/SQLite, en capas bronce/plata/oro: ingesta cruda, perfilado y hallazgos, reglas de limpieza (interpolación, detección de error de unidad, KPIs, semáforo), consultas de resultados, y el esquema en estrella para Power BI | Etapa 2 y 4 |
| [`etapa3_modelo_dimensional/`](etapa3_modelo_dimensional) | Diseño del modelo dimensional (metodología Kimball): documento con la tabla de hechos, las 3 dimensiones, y el diagrama del esquema en estrella | Etapa 3 |

Hubo una primera versión de la limpieza en Python/pandas (prototipo inicial), pero se descartó: hacía lo mismo que `etapa2_sql/` con menos trazabilidad, así que no tiene sentido mantener dos pipelines que resuelven el mismo problema. La versión en SQL es la única vigente.

## Flujo del proyecto

1. **Fuentes originales** (no se suben al repo por confidencialidad): `Bitacora descargas 2026.xlsx` (una hoja por planta, formato CONAGUA) y `ReportingFactory Ene26 - Oct26.xlsx` (exportación de la plataforma corporativa).
2. **Etapa 2** (`etapa2_sql/`): limpieza en SQL sobre SQLite, para que cada regla sea una consulta auditable. Termina en `fact_mensual` con los 4 KPI del reto y el semáforo.
3. **Etapa 3** (`etapa3_modelo_dimensional/`): diseño conceptual del modelo dimensional sobre `fact_mensual` — tabla de hechos `FACT_CONCILIACION_MENSUAL` y 3 dimensiones (`DIM_PLANTA`, `DIM_TIEMPO_MES`, `DIM_DIAGNOSTICO`).
4. **Etapa 4** (`etapa2_sql/modelo_estrella.sql` + `exportar_modelo_estrella.py`): materializa ese modelo dimensional como tablas físicas en la base y las exporta a Excel para conectar Power BI. El dashboard (`.pbix`) y el Excel con datos reales no se suben al repo por confidencialidad.

## KPIs y semáforo

Con p = planta, t = mes, volúmenes en litros:

- **KPI 1** Diferencia de descarga (L): `vol_total_l − rf_litros`
- **KPI 2** Desviación porcentual (%): `|diferencia| / rf_litros × 100`
- **KPI 3** Tasa de lecturas atípicas (%): lecturas con pico, cero o negativas / lecturas totales
- **KPI 4** Completitud (%): días con lectura real / días esperados del mes

Semáforo (implementado en `etapa2_sql/limpieza.sql`, regla R9 — el umbral 2%/5% del documento de alcance original es una propuesta pendiente de validar con Auditoría, esta es la regla que realmente corre):

```
ROJO     si hay error de unidad en Reporting Factory, o la desviación es mayor a 5%
AMARILLO si la desviación es mayor a 1% y la diferencia absoluta supera 5,000 L,
         o la completitud es menor a 100%, o Reporting Factory omite el riego
VERDE    en cualquier otro caso
```

Cada fila trae además una `causa_probable` en texto (ej. "RF capturado en m3 en lugar de litros", "Cierre de mes sin lectura (volumen estimado)") para que el semáforo sea explicable, no solo un color.
