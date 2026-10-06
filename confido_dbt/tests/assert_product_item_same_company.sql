-- tests/assert_product_item_same_company.sql

--Remote IDs are only unique per company, so I scope them by company. Internal IDs are Confido's primary keys, so they're unique on their own, and I added a test to catch any cross-company link

select p.product_id, p.company_detail_id as product_company, i.company_detail_id as item_company
from {{ ref('stg_confido__products') }} p
join {{ ref('stg_accounting__items') }} i on i.item_id = p.item_id
where p.company_detail_id is not null
  and p.company_detail_id <> i.company_detail_id