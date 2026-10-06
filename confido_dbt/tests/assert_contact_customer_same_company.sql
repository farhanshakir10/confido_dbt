-- A contact must never map to another company's private customer.
-- Shared customers (company_detail_id is null) are allowed for every company.
select
    c.contact_id,
    c.company_detail_id as contact_company,
    gc.global_customer_id,
    gc.company_detail_id as customer_company
from {{ ref('int_contacts__resolved_customer') }} c
join {{ ref('stg_confido__customers') }} gc
    on gc.global_customer_id = c.global_customer_id
where gc.company_detail_id is not null
  and gc.company_detail_id <> c.company_detail_id