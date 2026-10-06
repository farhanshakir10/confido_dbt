-- A default DC must be shared or belong to the same company as its customer.
select
    dc.default_distribution_center_id,
    d.company_detail_id as dc_company,
    gc.company_detail_id as customer_company
from {{ ref('int_customers__default_dc') }} dc
join {{ ref('stg_confido__distribution_centers') }} d
    on d.distribution_center_id = dc.default_distribution_center_id
join {{ ref('stg_confido__customers') }} gc
    on gc.global_customer_id = dc.global_customer_id
where d.company_detail_id is not null
  and gc.company_detail_id is not null
  and d.company_detail_id <> gc.company_detail_id