select
    item_id,
    item_remote_id,
    item_name,
    company_detail_id,
    line_type,
    product_map_status,
    product_match_count,
    current_timestamp()::timestamp_ntz as _dbt_loaded_at
from {{ ref('int_items__resolved_product') }}