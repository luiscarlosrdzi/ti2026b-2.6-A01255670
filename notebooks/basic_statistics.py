# Databricks notebook source
# MAGIC %md
# MAGIC # Basic statistics — Reto FEMSA Agua (synthetic)
# MAGIC
# MAGIC **Course:** TI2006B — MLOps in Databricks
# MAGIC **Student:** A01255670
# MAGIC **Branch:** `students/A01255670/stats`
# MAGIC
# MAGIC **Question.** How does the compliance deviation (% difference between reported discharge
# MAGIC and Reporting Factory) vary across plants?
# MAGIC
# MAGIC **Data source.** The real source files for the FEMSA Agua challenge
# MAGIC (`Bitacora descargas 2026.xlsx`, `ReportingFactory Ene26 - Oct26.xlsx`) are confidential and are
# MAGIC **not** committed to the repository (see `reto femsa agua/README.md`). To satisfy the "no
# MAGIC sensitive data" constraint of this activity, this notebook uses a **synthetic dataset** that
# MAGIC reproduces the shape of the real KPI (`desviacion_pct`, KPI 2 in the challenge) across three
# MAGIC anonymized plants and two months, generated with a fixed random seed.
# MAGIC
# MAGIC **Units.** `desviacion_pct` is a percentage (0–100). `volumen_l` is liters (synthetic).
# MAGIC
# MAGIC **Missing-value policy.** Rows with a missing `desviacion_pct` are excluded from the statistics
# MAGIC and reported separately; they are not imputed.
# MAGIC
# MAGIC **Conclusions.** See the Markdown cells after the statistics and charts below.

# COMMAND ----------

# MAGIC %md ### Setup
# MAGIC If pandas, NumPy or Plotly are not available in this cluster/serverless environment, uncomment
# MAGIC the `%pip` line below and re-run this cell before the imports.

# COMMAND ----------

# MAGIC %pip install plotly pandas numpy -q

# COMMAND ----------

import numpy as np
import pandas as pd
import plotly
import plotly.express as px

rng = np.random.default_rng(42)

plantas = ["Planta_A"] * 80 + ["Planta_B"] * 80 + ["Planta_C"] * 80
df = pd.DataFrame({
    "planta": plantas,
    "mes": (list(range(1, 9)) * 10) * 3,
    "desviacion_pct": np.round(rng.lognormal(0.8, 0.7, 240), 2),
})

# Simulate a handful of missing readings, same as the activity's fallback example
df.loc[[0, 50, 150], "desviacion_pct"] = np.nan

print("Versions:", np.__version__, pd.__version__, plotly.__version__)
print("Rows:", len(df))
print("Missing values:\n", df[["planta", "desviacion_pct"]].isna().sum())

# COMMAND ----------

# MAGIC %md ### Clean and validate

# COMMAND ----------

clean = df.dropna(subset=["planta", "desviacion_pct"]).copy()
if len(clean) < 2 or not np.isfinite(clean["desviacion_pct"]).all():
    raise ValueError("Need at least two finite desviacion_pct values")

print("Analyzed rows:", len(clean))
print(clean["desviacion_pct"].describe().round(2))
print("Median:", round(clean["desviacion_pct"].median(), 2))

by_planta = clean.groupby("planta")["desviacion_pct"].agg(["count", "mean", "median"]).round(2)
print(by_planta)
assert by_planta["count"].sum() == len(clean), "Grouped counts must reconcile with analyzed rows"

# COMMAND ----------

# MAGIC %md
# MAGIC **Expected for this synthetic run:** 240 raw rows, 3 missing `desviacion_pct`, 237 analyzed
# MAGIC rows. The grouped counts by `planta` must sum to 237.
# MAGIC
# MAGIC Rows are excluded (not imputed) because a missing reading usually means the plant did not
# MAGIC report for that period — imputing a deviation value would hide a completeness problem instead
# MAGIC of surfacing it, which matters for an audit/compliance use case like this one.

# COMMAND ----------

# MAGIC %md ### Interactive charts

# COMMAND ----------

histogram = px.histogram(
    clean, x="desviacion_pct", nbins=20,
    title="Distribution of compliance deviation (%)",
    labels={"desviacion_pct": "Deviation (%)"},
)
box = px.box(
    clean, x="planta", y="desviacion_pct",
    title="Deviation (%) by plant",
    labels={"desviacion_pct": "Deviation (%)", "planta": "Plant"},
)
histogram.show()
box.show()

# COMMAND ----------

# MAGIC %md
# MAGIC **Interpretation.**
# MAGIC - *From the statistics:* the mean deviation is noticeably above the median, which is consistent
# MAGIC   with the right-skewed shape in the histogram (a few plants/periods with large deviations pull
# MAGIC   the mean up) — this matches the lognormal generator used for the synthetic data.
# MAGIC - *From the box plot:* `Planta_A`, `Planta_B` and `Planta_C` are generated from the exact same
# MAGIC   distribution, so any visual difference between them in this synthetic run is sampling noise,
# MAGIC   not a real per-plant effect — a real dataset would need a statistical test before claiming one
# MAGIC   plant is "worse" than another.
# MAGIC - **Group sizes.** All three plants have equal counts here (80 raw rows each); a real extract
# MAGIC   would likely be unbalanced, which the summary should call out.
# MAGIC - **Limitation.** This is synthetic data with no real audit signal; it only demonstrates the
# MAGIC   statistics/visualization workflow, not an actual FEMSA Agua finding.
