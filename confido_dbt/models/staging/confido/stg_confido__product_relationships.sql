-- One row per parent → child product link (case → pack, pack → single, case → single).
select
    id                  as product_relationship_id,
    product_id          as parent_product_id,
    child_product_id,
    quantity            as child_quantity,
    _updated_at
from {{ source('confido', 'PRODUCT_RELATIONSHIPS') }}