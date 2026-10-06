---
name: dbt-naming-conventions
description: Naming conventions for the confido_dbt project. Use when creating, renaming, or reviewing any model, yml file, seed, singular test, column, CTE, or accepted-values status in this repo.
---

# dbt naming conventions

Follow these when adding or changing anything under `confido_dbt/models/`, `seeds/`, or `tests/`. When reviewing, flag violations and propose the conforming name. Don't rename existing columns in marts without asking: downstream consumers and the enforced contract depend on them.

## Files

| Layer | Pattern | Example |
|---|---|---|
| Staging | `stg_<source>__<entity_plural>.sql` | `stg_accounting__invoice_items.sql` |
| Intermediate | `int_<entity_plural>__<verb_or_description>.sql` | `int_items__resolved_product.sql` |
| Dimension | `dim_<entity_plural>.sql` | `dim_distribution_centers.sql` |
| Fact | `fct_<grain_plural>.sql` | `fct_invoice_line_items.sql` |
| Model yml | `_<folder>__models.yml` (one per folder) | `_intermediate__models.yml` |
| Source yml | `_<folder>__sources.yml` | `_staging__sources.yml` |
| Seed | `<entity>_<attribute_plural>.csv` | `item_line_types.csv` |
| Singular test | `assert_<what_must_be_true>.sql` | `assert_default_dc_same_company.sql` |

- Source names are the system: `accounting` (external, remote IDs) or `confido` (internal). Source table names stay as declared in the warehouse (uppercase).
- Use a double underscore only between the prefix group and the description (`stg_<source>__`, `int_<entity>__`). Everywhere else, use single underscores.
- Everything is lowercase snake_case. Spell out entity names in full (`distribution_center`, not `dc`).

## Columns

| Kind | Rule | Examples |
|---|---|---|
| Primary key | `<entity>_id`. Rename `id` in staging | `invoice_item_id`, `global_customer_id` |
| Foreign key | Same name as the PK it points to | `invoice_id`, `product_id` |
| Remote (accounting) ID | `<entity>_remote_id`, cast to `varchar` | `customer_remote_id`, `item_remote_id` |
| UUID | `<entity>_uuid` | `customer_uuid` |
| Name/label | `<entity>_name` | `customer_name`, `item_name` |
| Boolean | `is_` or `has_` prefix, cast to `boolean` | `is_test_invoice`, `is_fx_missing` |
| Date | `<event>_date` or `<event>_on_date` | `paid_on_date` |
| Timestamp | `<event>_at` | `created_at` |
| Money | `amount_<qualifier>` | `amount_original`, `amount_usd` |
| Currency | `currency_code` (ISO 4217) | |
| Mapping status | `<entity>_map_status` | `customer_map_status`, `product_map_status` |
| Categorical | `<thing>_type` | `line_type` |
| Pipeline metadata | Leading underscore | `_updated_at`, `_source_updated_at`, `_dbt_loaded_at` |

- A key keeps the same name in every layer. If the grain name changes (e.g. `invoice_item_id` becoming `invoice_line_item_id`), document why in the model's header comment.
- Don't use abbreviations other than these: `id`, `uuid`, `fx`, `usd`, `dc` (only inside existing names). New columns spell words out.

## Values

- Status and category values are lowercase snake_case strings: `direct`, `inherited_from_parent`, `unmapped`, `item_not_found`.
- Fallback values for missing joins follow the pattern `<entity>_not_found`. Use `unmapped` when the entity was found but has no mapping, and `unclassified` when there's no category.
- Every status column has an `accepted_values` test that lists every value.

## SQL

- Import CTEs at the top, one per ref, named for the entity without the layer prefix: `invoice_items as (select * from {{ ref('stg_accounting__invoice_items') }})`.
- Table aliases are short and derived from the CTE name (`ii`, `inv`, `c`, `i`, `dd`).
- Lowercase keywords. Put a single space before `as`; don't pad aliases into aligned columns.
- Group select columns under comment headers in this order: `-- keys`, the entity groups, `-- amounts`, `-- flags`, `-- metadata`.

## Known deviations to fix when touched

- `models/staging/sources.yml` should become `_staging__sources.yml`.
- `int_contacts__resolved_customer.remote_id` should become `contact_remote_id`.
- `int_customers__default_dc` and `dc_assignment` use `dc`. Keep them for now and spell it out in any new names.
