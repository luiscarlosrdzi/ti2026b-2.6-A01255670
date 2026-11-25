# Etapa 2 — Limpieza en SQL/SQLite

Pipeline bronce/plata/oro para la auditoría de descargas de agua (Reto FEMSA Agua), construido sobre `sqlite3` como alternativa/evolución al script `limpieza.py` en pandas.

| Archivo | Capa | Qué hace |
| --- | --- | --- |
| `ingesta.py` | Bronce | Lee los Excel originales (bitácora + Reporting Factory) y los vuelca sin transformar a tablas `raw_*` en SQLite |
| `exploracion.sql` | — | Perfilado y hallazgos (E1-E19): huecos, fórmulas rotas, negativos, picos, ceros, comparación bitácora vs RF |
| `limpieza.sql` | Plata/Oro | Reglas R1-R9: catálogo de plantas, calendario real, interpolación de lecturas faltantes, volumen diario, detección de error de unidad en RF, KPIs y semáforo |
| `resultados.sql` / `v1.sql` | Consumo | Consultas de resumen por planta, evolución mensual y validaciones de control |
| `runsql.py` | Utilidad | Ejecuta cualquier `.sql` contra la base e imprime el resultado |

## Cómo correrlo

Los Excel originales y la base generada (`femsa.db`) **no se suben al repo** por confidencialidad (ver `.gitignore` en la raíz). Para reproducir, coloca los dos Excel en esta carpeta (o ajusta las rutas) y corre:

```bash
pip install openpyxl
python ingesta.py "Bitacora descargas 2026.xlsx" "ReportingFactory Ene26 - Oct26.xlsx" femsa.db
python runsql.py femsa.db limpieza.sql
python runsql.py femsa.db exploracion.sql
python runsql.py femsa.db resultados.sql
python runsql.py femsa.db v1.sql
```
