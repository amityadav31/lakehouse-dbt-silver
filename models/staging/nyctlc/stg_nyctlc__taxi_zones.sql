-- TLC uses the literal 'N/A' for "no value" in the lookup; surface it as NULL.
select
    cast(location_id as int)                              as location_id,
    cast(nullif(trim(borough), 'N/A') as varchar(50))     as borough,
    cast(nullif(trim(zone), 'N/A') as varchar(100))       as zone_name,
    cast(nullif(trim(service_zone), 'N/A') as varchar(50)) as service_zone
from {{ source('nyctlc', 'nyc_tlc_taxi_zone_lookup') }}
