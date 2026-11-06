-- Every bronze trip with the first cleaning rule it fails (NULL = clean).
-- Order matters: a row gets one reason, the earliest that applies.
-- Rules are unit-tested in _intermediate.yml; mobility.trips / trips_rejected split on rejection_reason.
with trips as (
    select * from {{ ref('stg_nyctlc__yellow_trips') }}
),

zones as (
    select location_id from {{ ref('stg_nyctlc__taxi_zones') }}
)

select
    t.*,
    case
        when t.pickup_at is null or t.dropoff_at is null
            then 'missing_timestamp'
        when t.dropoff_at < t.pickup_at
            then 'dropoff_before_pickup'
        when year(t.pickup_at) <> t.source_year or month(t.pickup_at) <> t.source_month
            then 'pickup_outside_source_month'
        when datediff(minute, t.pickup_at, t.dropoff_at) > {{ var('max_trip_minutes', 1440) }}
            then 'implausible_duration'
        when t.trip_distance_miles < 0
            then 'negative_distance'
        when t.fare_amount < 0 or t.total_amount < 0
            then 'negative_amount'
        when pz.location_id is null
            then 'unknown_pickup_zone'
        when dz.location_id is null
            then 'unknown_dropoff_zone'
    end as rejection_reason
from trips as t
left join zones as pz on pz.location_id = t.pickup_location_id
left join zones as dz on dz.location_id = t.dropoff_location_id
