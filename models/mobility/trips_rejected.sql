-- Quarantine: bronze trips that failed a cleaning rule, kept with the reason so
-- rejection rates can be monitored and rules revisited. Not a gold input.
select
    cast(rejection_reason as varchar(30)) as rejection_reason,
    vendor_id,
    pickup_at,
    dropoff_at,
    passenger_count,
    trip_distance_miles,
    ratecode_id,
    store_and_fwd_flag,
    pickup_location_id,
    dropoff_location_id,
    payment_type,
    fare_amount,
    extra_amount,
    mta_tax_amount,
    tip_amount,
    tolls_amount,
    improvement_surcharge_amount,
    congestion_surcharge_amount,
    airport_fee_amount,
    total_amount,
    source_year,
    source_month,
    source_file,
    bronze_run_id,
    bronze_ingested_at
from {{ ref('int_trips__validated') }}
where rejection_reason is not null
