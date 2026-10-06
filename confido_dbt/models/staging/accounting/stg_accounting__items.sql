select
    id as item_id,
    remote_id::varchar as item_remote_id,
    name as item_name,
    company_detail_id,
    _updated_at
from {{ source('accounting', 'ITEMS') }}