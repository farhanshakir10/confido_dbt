select
    id as contact_id,
    remote_id::varchar as remote_id,
    parent_remote_id::varchar as parent_remote_id,
    global_customer_id,
    distribution_center_id,
    name as contact_name,
    company_detail_id,
    _updated_at
from {{ source('accounting', 'CONTACTS') }}