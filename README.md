# Confido – Invoice Line Items Model (dbt + Snowflake)

## Overview

This project builds `fct_invoice_line_items`: one row per invoice line, with remote IDs from the external accounting system mapped to Confido internal entities (products, global customers, distribution centers) where possible.

- **Grain:** one row per invoice line (`invoice_line_item_id`)
- **Amount:** dollar amount included (`amount_original`, `amount_usd`); quantity is excluded as allowed
- **Unmapped lines are kept and flagged, never dropped**

## How to run

```bash
source ../confido-dbt/bin/activate
pip install -r requirements.txt
dbt deps
dbt seed
dbt build
```

Rebuild the fact from scratch: `dbt build -s fct_invoice_line_items --full-refresh`

## Project structure

```
models/
├── staging/          # 1:1 with source tables: rename, cast, flag (views)
├── intermediate/     # mapping logic (views)
├── marts/
│   ├── facts/        # fct_invoice_line_items (incremental, contract enforced)
│   └── dimensions/   # dim_customers, dim_products, dim_distribution_centers, dim_items
└── audit/            # audit_unmapped_remote_ids: work queue for unmapped IDs (view)
seeds/
└── item_line_types.csv   # item → product / trade_spend / deduction / fee / adjustment / test
tests/                    # singular data tests
```

Naming: `stg_accounting__*` = accounting-system data (remote IDs), `stg_confido__*` = Confido master data (internal IDs).

### Lineage

```
stg_invoices ──────────────┐
stg_invoice_items ─────────┤
stg_contacts ──► int_contacts__resolved_customer ─┤
stg_items + stg_products + seed ──► int_items__resolved_product ─┼─► int_invoice_items__enriched ─► fct_invoice_line_items
stg_distribution_centers ──► int_customers__default_dc ──────────┘

fct_invoice_line_items + int_contacts__resolved_customer + dim_customers + dim_items ─► audit_unmapped_remote_ids
```

## Mapping logic

| Entity | Path | Rule |
|---|---|---|
| Customer | `invoices.customer_remote_id` → `contacts.remote_id` → `global_customer_id` | Join on `(company_detail_id, remote_id)`. If the contact has no customer, inherit from the parent contact. |
| Distribution center | `contacts.distribution_center_id`, else customer's "All Other DCs" | Contact DC column is empty today, so every mapped line uses the default and is flagged. |
| Product | `invoice_items.item_remote_id` → `items.remote_id` → `items.id` ← `products.item_id` | Mapped only when an item has exactly one product. Otherwise `product_id` is null and `item_id` is kept. |
| Line type | Seed `item_line_types.csv` keyed on `item_id` | Separates product sales from trade spend and fees. |

Every mapping has a status column so each null is explained:

- `customer_map_status`: `direct`, `inherited_from_parent`, `unmapped`, `contact_not_found`
- `product_map_status`: `mapped`, `ambiguous`, `no_product`, `item_not_found`
- `dc_assignment`: `direct`, `default`, `unmapped`

## Audit model

`audit_unmapped_remote_ids` is a work queue for data stewards: one row per unmapped remote ID (`entity_type`, `company_detail_id`, `remote_id`), with its line count and dollar impact so the largest gaps get fixed first.

- **Customers:** `unmapped` and `contact_not_found` remote IDs.
- **Items:** `ambiguous` and `item_not_found` items, plus `no_product` items whose `line_type` is `product`. Non-product items (EDLP, fees, etc.) are expected and excluded.
- **Suggested customer matches:** each unmapped contact is scored against every customer it may map to (shared customers or its own company's) with `JAROWINKLER_SIMILARITY` (0–100). The best match is suggested only when the score is ≥ 90.
- **`strong_match_count`** is the number of candidates scoring ≥ 90. A count of 1 is a clear match; more than 1 means the names are too close to choose automatically and need manual review.

Suggestions are never applied automatically.

## Results

| Metric | Value |
|---|---|
| Invoice lines | 2,527 (matches source) |
| Total `amount_original` | 8,329,402.21 (reconciles to source, rounded per line) |
| Customer mapped | 911 lines (901 direct, 10 inherited from parent) |
| Customer not mapped | 1,603 contact not found, 13 contact without customer |
| Product mapped | 1,651 lines |
| Product not mapped | 854 ambiguous, 22 non-product items |
| `amount_usd` null | 1 line (CAD invoice, no FX source) |

## Data findings
- **Impact:** of $8.33M in line amounts, ~$1.57M has no matching contact (hashed `GENERATED_` IDs) and ~$1.16M sits on ambiguous items.
- **No DC on the invoice path:** `contacts.distribution_center_id` is 100% null.
- **Items → products is 1:many:** Yogurt maps to 5 products, Ice cream to 2. A plain join inflates 2,527 lines to 5,853.
- **Non-product lines:** EDLP, Promo, Early Pay Discount, Spoils, Short-Ship, etc.
- **Currency:** null on ~69% of invoices; one invoice is CAD.

## Assumptions
- Child contacts inherit the parent's global customer (one level).
- Unknown DC → the customer's "All Other DCs" record (`dc_assignment = 'default'`).
- Ambiguous items are not allocated across products without a business rule.
- Null currency = USD; CAD has no FX rate, so `amount_usd` is null.
- `PAID_ON_DATE` is the reporting date.
- `item_line_types.csv` is based on item names and needs business confirmation.
- Remote IDs are unique only per company, so all joins are scoped by `company_detail_id`.

## Design decisions
- Staging keeps every column; rows are flagged, never filtered.
- Left joins throughout, so no line is dropped.
- Products are aggregated per item before joining, so fan-out is impossible.
- Incremental merge on `_source_updated_at` (latest loader timestamp across line, invoice, contact, item and DC), so late mapping fixes reprocess affected lines.
- Nulls + status columns instead of `-1` unknown members.

## Tests
- Fact row count equals source lines (no fan-out, no drops).
- Amount reconciles to source.
- Nulls only where a status column explains them.
- Cross-company checks on product, customer and DC mappings.
- New items without a `line_type` fail the build.

## Limitations
- Single schema due to access limits; production would split layers into schemas with grants.
- No FX rate source for non-USD invoices.
