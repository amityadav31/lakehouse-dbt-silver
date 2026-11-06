-- Open-Meteo default units: °C, mm, cm (snowfall), km/h. Units are put in the column names.
select
    cast(weather_date as date)                    as weather_date,
    cast(latitude as decimal(9, 6))               as latitude,
    cast(longitude as decimal(9, 6))              as longitude,
    cast(timezone as varchar(50))                 as timezone,
    cast(temperature_2m_max as decimal(5, 1))     as temperature_max_c,
    cast(temperature_2m_min as decimal(5, 1))     as temperature_min_c,
    cast(temperature_2m_mean as decimal(5, 1))    as temperature_mean_c,
    cast(precipitation_sum as decimal(6, 1))      as precipitation_mm,
    cast(rain_sum as decimal(6, 1))               as rain_mm,
    cast(snowfall_sum as decimal(6, 2))           as snowfall_cm,
    cast(wind_speed_10m_max as decimal(5, 1))     as wind_speed_max_kmh,
    cast(weather_code as int)                     as weather_code,
    cast(_source_file as varchar(200))            as source_file,
    cast(_run_id as varchar(100))                 as bronze_run_id,
    cast(_ingested_at as datetime2(6))            as bronze_ingested_at
from {{ source('openmeteo', 'open_meteo_weather_daily') }}
