-- One row per case that contains packs: the case's direct children that are packs.
-- Example: Strawberry Multipack (case) 2629 → 8 × Strawberry Multipack 772 = 8 packs per case.
select
    r.parent_product_id         as case_product_id,
    sum(r.child_quantity)       as packs_per_case
from {{ ref('stg_confido__product_relationships') }} r
join {{ ref('int_products__levels') }} parent
    on  parent.product_id    = r.parent_product_id
    and parent.product_level = 'case'
join {{ ref('int_products__levels') }} child
    on  child.product_id    = r.child_product_id
    and child.product_level = 'pack'
group by 1
