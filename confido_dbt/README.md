# Confido – Invoice Line Items Model (dbt + Snowflake)

## Overview

This project builds `fct_invoice_line_items`: one row per invoice line, with remote IDs from the external accounting system mapped to Confido internal entities (products, global customers, distribution centers) where possible.

- **Grain:** one row per invoice line (`invoice_line_item_id`)
- **Amount:** dollar amount included (`amount_original`, `amount_usd`); quantity is excluded as allowed
- **Unmapped lines are kept and flagged, never dropped**

## How to run

```bash
python3 -m venv .venv && source .venv/bin/activate
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
└── marts/
    ├── facts/        # fct_invoice_line_items (incremental, contract enforced)
    └── dimensions/   # dim_customers, dim_products, dim_distribution_centers, dim_items
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

- **Customer remote IDs mix integers and hashes** (`GENERATED_...`). The hashed IDs cover ~1,600 invoices and don't exist in Contacts.
- **No DC on the invoice path.** `contacts.distribution_center_id` is 100% null; invoices and items have no DC column.
- **One item can map to many products.** "Yogurt" maps to 5 products and "Ice cream" to 2. A plain join inflates 2,527 lines to 5,853 rows.
- **Some items are not products:** EDLP, Promo, Placement, Early Pay Discount, Retailer Spoils, Short-Ship, Services, A/R Clearing.
- **No invoice issue date.** `PAID_ON_DATE` is the only business date; `CREATED_AT` is a load timestamp.
- **Currency is null on ~69% of invoices** (one load batch); one invoice is in CAD.
- **`TOTAL_AMOUNT` ≠ `QUANTITY × UNIT_PRICE`** on ~1,700 lines, so `TOTAL_AMOUNT` is treated as the source of truth.
- **Test data present:** invoices like `TEST1`, `testDC`, `INVTESTSTAGING`; test items like "Test object".
- **Invoice `NUMBER` is not unique**, so `ID` is used as the key.
- **Two product names contain an HTML/XSS payload.** Flagged with `has_html_in_name`; BI tools must escape names.
- **`CHECK_REMIT_ITEM_ID` is 100% null.**
- **Contact and global customer names differ** (e.g. "UNFI West" → SuperValu). Reporting should use the global customer name.

## Assumptions

1. Child contacts inherit the parent contact's global customer.
2. Unknown DC defaults to the customer's "All Other DCs" record (`dc_assignment = 'default'`).
3. Ambiguous items stay at item level; no allocation across products without a business rule.
4. Non-product lines stay in the fact, tagged with `line_type`.
5. Null currency = USD (`is_currency_defaulted`). CAD has no FX rate, so `amount_usd` is null (`is_fx_missing`).
6. `PAID_ON_DATE` is the reporting date.
7. Test invoices are flagged (`is_test_invoice`), not deleted.
8. `item_line_types.csv` classifications are based on item names and should be confirmed by the business.
9. Remote IDs are unique only within a company, so all remote-ID joins are scoped by `company_detail_id`.

## Design decisions

- **Staging keeps every column**, renamed and typed. Rows are flagged, not filtered.
- **Left joins everywhere except invoice header**, so no line is ever dropped.
- **Products are aggregated per item before joining**, so fan-out is impossible by design.
- **Incremental fact (merge)** filtered on `_source_updated_at`, the latest `_updated_at` across the line, invoice, contact (including parent), item/products and DC. A late mapping fix reprocesses affected lines. Uses Snowflake's `GREATEST_IGNORE_NULLS` so unmapped lines aren't skipped.
- **Loader timestamp (`_UPDATED_AT`) drives incremental loads**, not the source `UPDATED_AT`, which can arrive late.
- **Model contract enforced** on the fact, with explicit types and `on_schema_change = 'fail'`.
- **Nulls + status columns** instead of `-1` unknown members, so gaps stay visible and auditable.

## Tests

- **Sources and staging:** `unique` / `not_null` on primary keys; invoice lines → invoices relationship.
- **Intermediate:** one row per key on every mapping model; accepted values on status columns; `(company_detail_id, remote_id)` unique in contacts.
- **Fact:**
  - `equal_rowcount` vs source lines (no fan-out, no dropped lines)
  - amount reconciles to source
  - `relationships` to every dimension (nulls allowed)
  - nulls only where the status column explains them
- **Cross-company checks:** product ↔ item, contact ↔ customer, and default DC ↔ customer must belong to the same company (or be shared).
- **Seed coverage:** a new item without a `line_type` fails the build instead of being labelled silently.

Incremental logic verified: a second run with no source changes processes 0 rows.

## Limitations and production improvements

- **Schemas:** all models are in one schema due to access limits. In production, layers would be separated into schemas inside an environment database, with analysts granted read access to marts only (`+schema`, `+grants`).
- **Store test failures** (`--store-failures`) in an audit schema.
- **Audit model** listing unmapped remote IDs with suggested matches (`JAROWINKLER_SIMILARITY`) for human review, e.g. "Loblaw" and "Kroger" contacts.
- **FX rates** source to populate `amount_usd` for non-USD invoices.
- **Snapshots (SCD2)** on contacts and products if mappings need point-in-time history.
- **Deletes** aren't caught by the incremental filter; a periodic full refresh covers them.
- **Out of scope:** Retailers, Product_Prices, Product_Shipping_Config, Product_Relationship. Possible extensions: price variance vs list price, and case-to-unit (BOM) explosion.
