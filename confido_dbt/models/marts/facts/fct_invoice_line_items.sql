-- Key: invoice_item_id is Confido's internal primary key, already unique across companies, so no surrogate key is needed.
-- Every column is cast, so types match the contract exactly.
-- amount_usd is null for CAD instead of guessing a rate. is_fx_missing flags it, and amount_original keeps the real value.
-- Quantity is dropped, as the instructions allowed.
-- on_schema_change = 'fail' is required with an enforced contract on incremental models. It stops silent schema drift.


{{ config(
    materialized         = 'incremental',
    incremental_strategy = 'merge',
    unique_key           = 'invoice_line_item_id',
    on_schema_change     = 'fail'
) }}

with enriched as (

    select * from {{ ref('int_invoice_items__enriched') }}

    {% if is_incremental() %}
    -- only lines where the line, invoice, contact, item, product or DC changed
    where _source_updated_at > (select max(_source_updated_at) from {{ this }})
    {% endif %}

)

select
    -- keys
    invoice_item_id::number(38,0) as invoice_line_item_id,
    invoice_id::number(38,0) as invoice_id,
    invoice_number::varchar as invoice_number,
    paid_on_date::date as paid_on_date,
    company_detail_id::number(38,0) as company_detail_id,

    -- Confido internal entities
    contact_id::number(38,0) as contact_id,
    global_customer_id::number(38,0) as global_customer_id,
    distribution_center_id::number(38,0) as distribution_center_id,
    item_id::number(38,0) as item_id,
    product_id::number(38,0) as product_id,
    line_type::varchar as line_type,

    -- remote IDs kept for lineage back to the accounting system
    customer_remote_id::varchar as customer_remote_id,
    item_remote_id::varchar as item_remote_id,

    -- amounts
    currency_code::varchar as currency_code,
    round(amount_original, 2)::number(18,2) as amount_original,
    iff(currency_code = 'USD',
        round(amount_original, 2), null)::number(18,2) as amount_usd,

    -- mapping status
    customer_map_status::varchar as customer_map_status,
    product_map_status::varchar as product_map_status,
    dc_assignment::varchar as dc_assignment,

    -- flags
    (amount_original < 0)::boolean as is_credit,
    is_test_invoice::boolean as is_test_invoice,
    is_currency_defaulted::boolean as is_currency_defaulted,
    (currency_code <> 'USD')::boolean as is_fx_missing,

    -- metadata
    _source_updated_at::timestamp_ntz as _source_updated_at,
    current_timestamp()::timestamp_ntz as _dbt_loaded_at

from enriched