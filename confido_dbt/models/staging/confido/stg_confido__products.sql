select
    id as product_id,
    _uuid as product_uuid,
    name as product_name,
    type as product_type,
    item_id,
    upc,
    cleaned_upc,
    product_family_id,
    internal_item_number,
    ship_with_product_relationship_id,
    company_detail_id,
    regexp_like(name, '.*<[^>]+>.*') as has_html_in_name,
    updated_at as source_updated_at,
    _updated_at
from {{ source('confido', 'PRODUCTS') }}