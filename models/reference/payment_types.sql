-- Published, contracted copy of the payment_types seed (seeds can't carry contracts).
select
    cast(payment_type as int)               as payment_type,
    cast(payment_type_name as varchar(30))  as payment_type_name
from {{ ref('tlc_payment_types') }}
