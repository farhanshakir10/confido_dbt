select
    id as distribution_center_id,
    _uuid as dc_uuid,
    name as dc_name,
    global_customer_id,
    muffin_location_id,
    company_detail_id,
    name = 'All Other DCs' as is_default_dc,
    _updated_at
from {{ source('confido', 'CONFIDO_DISTRIBUTION_CENTERS') }}