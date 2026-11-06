# lakehouse-dbt-silver

dbt project for the **silver** Warehouse (`wh_silver`) of the Week 1 medallion lakehouse.
Fabric items (lakehouses, notebooks, warehouses, pipeline) live in
[amityadav31/lakehouse](https://github.com/amityadav31/lakehouse); this repo holds only the dbt code,
because a Fabric dbt job connected to GitHub needs `dbt_project.yml` at the repo root.

```
lh_bronze_* (SQL endpoint) → staging.stg_*                        views: rename + type (private)
                           → staging.int_trips__validated         view: rejection_reason per trip (private)
                           → mobility.trips / trips_rejected      tables, contracted
                           → reference.zones, payment_types       tables, contracted
                           → environment.weather_daily            table, contracted
```

- Gold projects read only `mobility`, `reference`, `environment` (`access: public`), never `staging`.
- Each trip gets the **first** rule it fails: `missing_timestamp`, `dropoff_before_pickup`,
  `pickup_outside_source_month`, `implausible_duration` (> 24 h), `negative_distance`, `negative_amount`,
  `unknown_pickup_zone`, `unknown_dropoff_zone`. Clean → `mobility.trips`; failed → `mobility.trips_rejected`.
- Rules are dbt unit tests in `models/intermediate/_intermediate.yml`.

## Fabric quirks handled here

| Issue | Fix |
|---|---|
| Concurrent DDL in one Warehouse deadlocks (error 1205) | `threads: 1` (profile locally, job setting in Fabric) |
| dbt's unit-test temp tables survive the end-of-test ROLLBACK (Fabric DDL is transactional) | `macros/materializations/unit_fabric.sql` |
| Unit tests fail in the Fabric dbt job with error 16214 "Nested CTE cannot be used in this query" (dbt wraps the fixture CTEs in another `WITH`) | same macro: test SQL goes into a temp view, no nested `WITH` |
| dbt's default schema naming gives `dbo_mobility` | `macros/generate_schema_name.sql` |

## Run in Fabric (dbt job `dbt_silver`, workspace folder `02_silver`)

New item → dbt job → **Connect to a GitHub project** → this repo, branch `main`, classic PAT,
adapter **Fabric Data Warehouse**, target `wh_silver`, threads **1**, command `dbt build`.
`profiles.yml` is ignored there; the job supplies the connection.
Fabric's runtime is dbt-core 1.11 + dbt-fabric 1.10 (local dev below uses 1.12).

## Run locally

dbt Core + dbt-fabric, **not** dbt Fusion (`dbt --version` must say `Core:`).

```bash
python3.13 -m venv .venv-dbt && source .venv-dbt/bin/activate
pip install -r requirements.txt      # cert error? export SSL_CERT_FILE=$(python -m certifi)
az login --tenant <fabric-tenant-id> --use-device-code --allow-no-subscriptions
export FABRIC_SQL_ENDPOINT=<id>.datawarehouse.fabric.microsoft.com   # wh_silver → Settings → SQL endpoint
dbt debug
dbt build
```

Refresh the bronze SQL analytics endpoints first if bronze was just reloaded.
