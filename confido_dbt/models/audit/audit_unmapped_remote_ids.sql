with fct as (

    select * from {{ ref('fct_invoice_line_items') }}

),

-- Customers that didn't map, with business impact
unmapped_customers as (

    select
        'customer' as entity_type,
        company_detail_id,
        customer_remote_id as remote_id,
        customer_map_status as map_status,
        count(*) as line_count,
        sum(amount_original) as amount_impacted
    from fct
    where customer_map_status in ('unmapped', 'contact_not_found')
    group by all

),

-- Items that didn't resolve to a single product
-- (non-product items like EDLP are expected, so they're excluded)
unmapped_items as (

    select
        'item' as entity_type,
        company_detail_id,
        item_remote_id as remote_id,
        product_map_status as map_status,
        count(*) as line_count,
        sum(amount_original) as amount_impacted
    from fct
    where product_map_status in ('ambiguous', 'item_not_found')
       or (product_map_status = 'no_product' and line_type = 'product')
    group by all

),

-- Score every unmapped contact against every customer it's allowed to match
scored as (

    select
        c.company_detail_id,
        c.remote_id,
        gc.global_customer_id,
        gc.customer_name,
        jarowinkler_similarity(lower(c.contact_name), lower(gc.customer_name)) as match_score
    from {{ ref('int_contacts__resolved_customer') }} c
    cross join {{ ref('dim_customers') }} gc
    where c.customer_map_status = 'unmapped'
      -- only shared customers or the contact's own company
      and (gc.company_detail_id is null or gc.company_detail_id = c.company_detail_id)

),

-- One row per contact: its best match, and how many strong matches exist
customer_suggestions as (

    select
        company_detail_id,
        remote_id,
        max(match_score)                          as match_score,
        max_by(global_customer_id, match_score)   as suggested_id,
        max_by(customer_name, match_score)        as suggested_name,
        count_if(match_score >= 90)               as strong_match_count
    from scored
    group by company_detail_id, remote_id

),

contacts as (

    select company_detail_id, remote_id, contact_name
    from {{ ref('int_contacts__resolved_customer') }}

),

items as (

    select company_detail_id, item_remote_id, item_name, product_match_count
    from {{ ref('dim_items') }}

),

final as (

    select
        u.entity_type,
        u.company_detail_id,
        u.remote_id,
        c.contact_name as remote_name,
        u.map_status,
        u.line_count,
        u.amount_impacted,
        null::number as candidate_product_count,
        iff(s.match_score >= 90, s.suggested_id, null) as suggested_global_customer_id,
        iff(s.match_score >= 90, s.suggested_name, null) as suggested_customer_name,
        s.match_score,
        s.strong_match_count
    from unmapped_customers u
    left join contacts c
        on  c.remote_id         = u.remote_id
        and c.company_detail_id = u.company_detail_id
    left join customer_suggestions s
        on  s.remote_id         = u.remote_id
        and s.company_detail_id = u.company_detail_id

    union all

    select
        u.entity_type,
        u.company_detail_id,
        u.remote_id,
        i.item_name as remote_name,
        u.map_status,
        u.line_count,
        u.amount_impacted,
        i.product_match_count as candidate_product_count,
        null as suggested_global_customer_id,
        null as suggested_customer_name,
        null as match_score,
        null as strong_match_count
    from unmapped_items u
    left join items i
        on  i.item_remote_id    = u.remote_id
        and i.company_detail_id = u.company_detail_id

)

select
    *,
    current_timestamp()::timestamp_ntz as _dbt_loaded_at
from final