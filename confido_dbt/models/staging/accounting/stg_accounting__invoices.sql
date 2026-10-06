select
    id as invoice_id,
    number::varchar as invoice_number,
    customer_remote_id::varchar as customer_remote_id,
    subsidiary_id,
    company_detail_id,
    paid_on_date::date as paid_on_date,
    check_remit_item_id,

    upper(currency) as currency_code_raw,
    coalesce(upper(currency), 'USD') as currency_code,
    currency is null as is_currency_defaulted,

    number ilike any ('%test%', '%repay%') as is_test_invoice,

    created_at,
    _updated_at
from {{ source('accounting', 'INVOICES') }}