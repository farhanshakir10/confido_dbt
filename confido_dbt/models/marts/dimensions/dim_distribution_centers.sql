select
    distribution_center_id,
    dc_name,
    global_customer_id,
    company_detail_id,
    is_default_dc,
    current_timestamp()::timestamp_ntz as _dbt_loaded_at
from {{ ref('stg_confido__distribution_centers') }}