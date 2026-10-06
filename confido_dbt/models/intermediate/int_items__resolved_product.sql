with items as (

    select * from {{ ref('stg_accounting__items') }}

),

products_per_item as (

    -- one row per item: how many products point to it
    select
        item_id,
        count(*) as product_match_count,
        min(product_id) as only_product_id,
        max(_updated_at) as products_updated_at
    from {{ ref('stg_confido__products') }}
    where item_id is not null
    group by item_id

),

line_types as (

    select * from {{ ref('item_line_types') }}

)

select
    i.item_id,
    i.item_remote_id,
    i.item_name,
    i.company_detail_id,

    coalesce(p.product_match_count, 0) as product_match_count,
    iff(p.product_match_count = 1, p.only_product_id, null) as product_id,

    case
        when p.product_match_count = 1 then 'mapped'
        when p.product_match_count > 1 then 'ambiguous'
        else 'no_product'
    end as product_map_status,

    coalesce(lt.line_type, 'unclassified') as line_type,

    -- latest change to either the item or any product linked to it
    greatest_ignore_nulls(i._updated_at, p.products_updated_at) as _updated_at

from items i
left join products_per_item p  on p.item_id  = i.item_id
left join line_types lt        on lt.item_id = i.item_id