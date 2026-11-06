select
    weather_date,
    latitude,
    longitude,
    timezone,
    temperature_max_c,
    temperature_min_c,
    temperature_mean_c,
    precipitation_mm,
    rain_mm,
    snowfall_cm,
    wind_speed_max_kmh,
    weather_code,
    source_file,
    bronze_run_id,
    bronze_ingested_at
from {{ ref('stg_openmeteo__weather_daily') }}
