select
    global_customer_id,
    distribution_center_id as default_distribution_center_id,
    _updated_at
from {{ ref('stg_confido__distribution_centers') }}
where is_default_dc
qualify row_number() over (
    partition by global_customer_id
    order by distribution_center_id
) = 1