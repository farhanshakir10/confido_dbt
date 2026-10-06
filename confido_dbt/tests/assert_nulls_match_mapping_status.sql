-- Every null ID must be explained by its status column.
-- Any row returned is an unexplained null (a bug in the mapping logic).
select invoice_line_item_id, product_map_status, customer_map_status, dc_assignment
from {{ ref('fct_invoice_line_items') }}
where (product_id is null             and product_map_status  =  'mapped')
   or (product_id is not null         and product_map_status  <> 'mapped')
   or (global_customer_id is null     and customer_map_status in ('direct', 'inherited_from_parent'))
   or (distribution_center_id is null and dc_assignment       <> 'unmapped')
   or (amount_usd is null             and currency_code       =  'USD')