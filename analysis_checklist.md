# Excel analysis checklist

Use Excel or Power Query to document these checks and create PivotTables.

## Data-quality checks
- [ ] Check row counts before and after transformations.
- [ ] Identify duplicate IDs at the correct table grain.
- [ ] Count missing values in key fields.
- [ ] Standardize date formats and data types.
- [ ] Check invalid date sequences.
- [ ] Check orphan IDs before merging tables.
- [ ] Reconcile totals with SQL/Python outputs.

## Suggested PivotTables
1. Monthly order count and item sales value.
2. Item sales value by product category.
3. Order count by customer state.
4. Late-delivery percentage by month or state.
5. Average review score by delivery status.
6. Payment value by payment type.

## Example formula
If invoice/order IDs are in column A, a duplicate flag can be created with:
`=IF(COUNTIF($A:$A,A2)>1,"Duplicate","Unique")`

Check the business key and table grain before treating repeated IDs as errors: repeated order IDs are expected in order-item tables.
