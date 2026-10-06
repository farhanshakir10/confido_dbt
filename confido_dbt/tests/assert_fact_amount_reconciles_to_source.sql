-- Total dollars in the fact must equal total dollars in the source.
-- Catches fan-out (inflated totals) and dropped lines (missing totals).
with source_total as (
    select sum(round(amount_original, 2)) as amount
    from {{ ref('stg_accounting__invoice_items') }}
),

fact_total as (
    select sum(amount_original) as amount
    from {{ ref('fct_invoice_line_items') }}
)

select s.amount as source_amount, f.amount as fact_amount
from source_total s
cross join fact_total f
where s.amount <> f.amount