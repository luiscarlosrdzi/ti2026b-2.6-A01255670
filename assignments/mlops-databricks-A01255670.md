# MLOps in Databricks — evidence (A01255670)

TI2006B · Fall 2026 · Individual activity: basic statistics, Plotly, GitHub, and Jobs.

Notebook: [`notebooks/basic_statistics.py`](../notebooks/basic_statistics.py) (Databricks source format).
Branch: `students/A01255670/stats`.

## 1. Tool investigation

| Tool | Purpose | How it connects here | Access/cost consideration | Limitation | Reference |
| --- | --- | --- | --- | --- | --- |
| **GitHub** | Hosts and versions the notebook source (`.py`/`.ipynb`) with commit history and branches. | Databricks Git folder is linked to this GitHub repo via a Git credential (PAT or GitHub App); the student branch holds the notebook. | Free for public/academic repos; private repos and GitHub Apps need an org admin to approve installation. | No code execution by itself — it only stores and diffs files. | https://docs.github.com/repositories |
| **GitLab** | Same role as GitHub (repo hosting, branches, MRs) but with a different platform/UI and built-in CI runners. | Would replace GitHub as the Git remote; Databricks also supports GitLab as a Git provider for Git folders. | Free tier includes private repos and CI minutes; self-hosting is possible, unlike GitHub. | Smaller ecosystem of third-party integrations than GitHub. | https://docs.gitlab.com/ee/user/project/repository/ |
| **Databricks Jobs (Lakeflow Jobs)** | Executes the notebook on managed/serverless compute as a scheduled or on-demand task, producing a run with status and logs. | The Job's notebook task points at the workspace path of the notebook pulled into the Git folder; running it re-executes the code that GitHub stores. | Serverless compute in Free Edition has fair-use quotas; paid tiers bill per compute used. | Doesn't version code — it only runs whatever is currently in the workspace path (or a pinned Git ref). | https://learn.microsoft.com/azure/databricks/jobs/ |
| **GitHub Actions** | Runs checks (lint, syntax, tests) automatically on push/PR, inside GitHub's own compute. | A workflow in `.github/workflows/` could run `python -m py_compile` or `nbformat` checks on this notebook on every push to `students/**`. | Free minutes for public repos; private repos have a monthly quota. | Not meant for long-running data jobs against a Databricks cluster — it's for fast CI checks, not production execution. | https://docs.github.com/actions |

**Why GitHub stores and Databricks Jobs executes.** In this reference workflow, GitHub is the source
of truth for the notebook's text/history (who changed what, when, and why), while Databricks Jobs is
the only one of the two with access to the compute, data, and credentials needed to actually run the
notebook against real data. Separating "where the code lives" from "where the code runs" lets the
same reviewed commit be re-run deterministically, and lets access to data stay inside Databricks
instead of being copied into the CI runner.

**When GitHub Actions would help.** For this kind of notebook, a lightweight Actions workflow would
be useful to catch a trivial break (syntax error, bad import, notebook that doesn't parse) on every
push, *before* anyone spends Databricks compute minutes running a broken notebook as a Job.

## 2. Statistics and charts

See the notebook (`notebooks/basic_statistics.py`) for the full Markdown narrative, code and two
Plotly charts (histogram + box plot) over the synthetic `desviacion_pct` dataset. Fill in after running
it interactively in Databricks:

- Total rows: `240` · Missing `desviacion_pct`: `3` · Analyzed rows: `237`
- Mean: `2.66` · Median: `2.08` · Sample std: `2.06` · Min: `0.50` · Max: `17.11` · Q1: `1.38` · Q3: `3.23`
- Grouped counts by `planta` reconcile to `237`: **yes** — `Planta_A: 78 (mean 2.61, median 2.37)`,
  `Planta_B: 79 (mean 2.56, median 1.90)`, `Planta_C: 80 (mean 2.80, median 2.02)`; `78+79+80 = 237`.

## 3. GitHub workflow evidence

- Repository: https://github.com/luiscarlosrdzi/ti2026b-2.6-A01255670
- Student branch: `students/A01255670/stats`
- Notebook path: `notebooks/basic_statistics.py`
- First commit (push) ID: `TBD`
- Second commit (small edit, pulled back into Databricks) ID: `TBD`
- Screenshot: Databricks Git folder connected to this repo/branch — `TBD`
- Screenshot: notebook visible on GitHub after push — `TBD`
- Screenshot: changed text visible in Databricks after pull — `TBD`

## 4. Databricks Job evidence

- Job name: `stats-A01255670`
- Task name: `basic_statistics` (type: Notebook, source: Workspace)
- Commit ID checked out when the Job ran: `TBD`
- Run ID / status: `TBD`
- Reconciled statistic (matches interactive run): `TBD`

## 5. Alert evidence

- Alert name: `stats-A01255670-missing-rate`
- Condition: e.g. missing-row count (or a query result) above a threshold
- Screenshot of alert configuration and a triggered/evaluated notification: `TBD`

## Reflection

- **What must stay the same to reproduce these statistics?** The random seed (`42`), the generator
  parameters (`lognormal(0.8, 0.7, 240)`), the group sizes (80 rows per plant), and the package
  versions printed at the top of the notebook run.
- **What was checked beyond the Job's success status?** That the Job's printed statistics
  (`describe()`, median, per-plant counts) numerically match the interactive run on the same commit,
  and that the grouped counts reconcile to the analyzed row count.
