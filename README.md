1) Connect to the 'dsp_university' database or create it using 01_create_database.sql (run in 'postgres').
2) DROP the previous schema if you used v1: open Query Tool in dsp_university and run 06_drop_all.sql from the first pack.
3) Open and run 02b_schema_versioned.sql to create the versioned schema.
4) Open and run 04b_seed_versioned.sql to insert data showing changed course HP and changed salaries.
5) Open and run 05b_reports_versioned.sql to verify:
   - IV1351 P1 uses HP 7.5 (layout version 1), IV1351 P2 uses HP 15.0 (layout version 2)
   - Salary versioning affects costs (employee 2 has version 2 in P2 only)
6) All rules and constraints are enforced by the database. No hardcoding in applications is needed.
