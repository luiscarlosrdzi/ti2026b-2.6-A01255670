# Fase 1 — Limpieza en Python (pandas)

Primera versión de la limpieza, previa a la reconstrucción en SQL de `etapa2_sql/`.

`limpieza.py` lee los dos Excel originales (bitácora en formato CONAGUA + exportación de Reporting Factory), calcula el volumen diario y mensual por planta (con arrastre de la última lectura válida cuando falta un día), convierte Reporting Factory de litros a m³, y concilia ambas fuentes por planta-mes, clasificando cada combinación (incluida la detección del error de capturar en m3 en vez de litros).

## Cómo correrlo

Los Excel originales y el archivo de salida (`datos_limpios.xlsx`) **no se suben al repo** por confidencialidad. Coloca los dos Excel junto al script (o ajusta las rutas) y corre:

```bash
pip install pandas openpyxl
python limpieza.py
```

Genera `datos_limpios.xlsx` con 4 hojas: `Bitacora_diaria`, `Bitacora_mensual`, `ReportingFactory`, `Conciliacion`.
