--Inner join only to invoices, since every line must have one (your staging test proves this). Left join everything else so no line is ever dropped.-
--This ensures that even if a contact, item, or distribution center is missing, the invoice item still appears in the result set.
--contact_not_found (remote ID not in Contacts) is different from unmapped (contact found, but no customer). That separates "missing in Contacts" from "missing a mapping."
--Remote-ID joins (contacts, items) use company_detail_id. Internal-ID joins (DC, subsidiary) don't need it.

with invoice_items as (
    select * from {{ ref('stg_accounting__invoice_items') }}
),

invoices as (
    select * from {{ ref('stg_accounting__invoices') }}
),

contacts as (
    select * from {{ ref('int_contacts__resolved_customer') }}
),

items as (
    select * from {{ ref('int_items__resolved_product') }}
),

default_dcs as (
    select * from {{ ref('int_customers__default_dc') }}
)

select
    -- keys
    ii.invoice_item_id,
    ii.invoice_id,
    inv.invoice_number,
    inv.company_detail_id,
    inv.subsidiary_id,
    inv.paid_on_date,

    -- customer
    inv.customer_remote_id,
    c.contact_id,
    c.contact_name,
    c.global_customer_id,
    coalesce(c.customer_map_status, 'contact_not_found') as customer_map_status,

    -- distribution center: direct if the contact has one, else the customer's default
    coalesce(c.distribution_center_id,
             dd.default_distribution_center_id) as distribution_center_id,
    case
        when c.distribution_center_id is not null         then 'direct'
        when dd.default_distribution_center_id is not null then 'default'
        else 'unmapped'
    end as dc_assignment,

    -- item / product
    ii.item_remote_id,
    i.item_id,
    i.item_name,
    i.product_id,
    coalesce(i.product_map_status, 'item_not_found') as product_map_status,
    coalesce(i.line_type, 'unclassified') as line_type,

    -- amounts
    inv.currency_code,
    inv.is_currency_defaulted,
    ii.amount_original,

    -- flags
    inv.is_test_invoice,

    -- latest change to anything that affects this line
    greatest_ignore_nulls(
        ii._updated_at,
        inv._updated_at,
        c._updated_at,
        i._updated_at,
        dd._updated_at
    ) as _source_updated_at

from invoice_items ii
join invoices inv
    on inv.invoice_id = ii.invoice_id
left join contacts c
    on  c.remote_id         = inv.customer_remote_id
    and c.company_detail_id = inv.company_detail_id
left join default_dcs dd
    on dd.global_customer_id = c.global_customer_id
left join items i
    on  i.item_remote_id    = ii.item_remote_id
    and i.company_detail_id = inv.company_detail_id