select
    id as invoice_item_id,
    invoice_id,
    item_remote_id::varchar as item_remote_id,
    total_amount as amount_original,
    quantity,
    unit_price,
    _updated_at
from {{ source('accounting', 'INVOICE_ITEMS') }}