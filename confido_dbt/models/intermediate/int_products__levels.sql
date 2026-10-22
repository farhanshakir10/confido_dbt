-- One row per product with its packaging level.
--   case    : type = 'CaseV2'
--   shipper : type = 'ShipperProduct'
--   pack    : no type, but contains other products (e.g. a 4-cup multipack)
--   single  : no type and contains nothing
with products as (
    select * from {{ ref('stg_confido__products') }}
),

parents as (
    select distinct parent_product_id
    from {{ ref('stg_confido__product_relationships') }}
)

select
    p.product_id,
    p.product_name,
    p.product_type,
    case
        when p.product_type = 'CaseV2'          then 'case'
        when p.product_type = 'ShipperProduct'  then 'shipper'
        when pr.parent_product_id is not null   then 'pack'
        else 'single'
    end                                         as product_level,
    p._updated_at
from products p
left join parents pr
    on pr.parent_product_id = p.product_id