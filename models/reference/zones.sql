select
    location_id,
    borough,
    zone_name,
    service_zone
from {{ ref('stg_nyctlc__taxi_zones') }}
