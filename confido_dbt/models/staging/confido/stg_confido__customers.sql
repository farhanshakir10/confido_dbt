select
    id as global_customer_id,
    _uuid as customer_uuid,
    name as customer_name,
    is_distributor::boolean as is_distributor,
    company_detail_id,
    _updated_at
from {{ source('confido', 'GLOBAL_CUSTOMERS') }}