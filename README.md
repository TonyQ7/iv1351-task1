# IV1351 Task 1

## Run order (pgAdmin → Query Tool)
1) `create_db.sql`
2) `views.sql`
3) `insert_data.sql`
4) `example_queries.sql` *(optional – used to produce the report screenshots)*

### What’s included
- **Schema & constraints**: tables, keys, manager/supervisor FKs, trigger to block derived planned activities, trigger to enforce max instances per teacher per period (config in `allocation_rule`, default 4).
- **Views & functions**: required-hours (with/without prep), teacher load per period, allocation costs using period-correct salary.
- **Seed data**: study periods, activities with factors, courses, layout versions, two demo instances (e.g., per handout), salaries, coefficients.
- **Example queries**: reproduce Admin 67 vs 82 (layout change) and different costs after salary change.

> Note: Any “rule=2 demo” that intentionally fails the 3rd allocation is *not* auto-run; it was used only to capture evidence for the report.
