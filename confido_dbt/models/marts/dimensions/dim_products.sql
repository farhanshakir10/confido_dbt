select
    product_id,
    product_name,
    product_type,
    item_id,
    product_family_id,
    upc,
    cleaned_upc,
    company_detail_id,
    has_html_in_name,
    current_timestamp()::timestamp_ntz as _dbt_loaded_at
from {{ ref('stg_confido__products') }}