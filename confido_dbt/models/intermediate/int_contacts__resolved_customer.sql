with contacts as (

    select * from {{ ref('stg_accounting__contacts') }}

)

select
    c.contact_id,
    c.remote_id,
    c.parent_remote_id,
    c.contact_name,
    c.company_detail_id,
    c.distribution_center_id,

    c.global_customer_id as direct_global_customer_id,
    p.global_customer_id as parent_global_customer_id,
    coalesce(c.global_customer_id, p.global_customer_id) as global_customer_id,

    case
        when c.global_customer_id is not null then 'direct'
        when p.global_customer_id is not null then 'inherited_from_parent'
        else 'unmapped'
    end as customer_map_status,

    -- latest change to either the contact or its parent
    greatest_ignore_nulls(c._updated_at, p._updated_at) as _updated_at

from contacts c
left join contacts p
    on  p.remote_id         = c.parent_remote_id
    and p.company_detail_id = c.company_detail_id