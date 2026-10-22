-- One row per invoice line, with quantities in cases and packs.
-- Assumption: the invoice QUANTITY is in units of the mapped product, which is a case for every mapped item today.
-- packs = cases × packs per case; null when the case has no pack level (e.g. Vanilla case = 8 cups directly).

with lines as (

    select
        e.*,
        l.product_level,
        iff(l.product_level = 'case', e.quantity, null)     as quantity_cases
    from {{ ref('int_invoice_items__enriched') }} e
    left join {{ ref('int_products__levels') }} l
        on l.product_id = e.product_id

)

select
    ln.*,
    ln.quantity_cases * pc.packs_per_case                   as quantity_packs,
    case
        when ln.product_id is null          then 'no_product'
        when ln.product_level = 'case'      then 'converted'
        else 'not_a_case'
    end                                                     as quantity_status
from lines ln
left join {{ ref('int_products__packs_per_case') }} pc
    on pc.case_product_id = ln.product_id