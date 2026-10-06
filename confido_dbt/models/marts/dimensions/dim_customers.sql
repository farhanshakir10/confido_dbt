select
    global_customer_id,
    customer_name,
    is_distributor,
    company_detail_id,
    company_detail_id is null as is_shared_customer,
    current_timestamp()::timestamp_ntz as _dbt_loaded_at
from {{ ref('stg_confido__customers') }}