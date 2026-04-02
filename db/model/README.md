# Physical data model package

This package contains:

- `payroll_compliance.dbml` - dbdiagram.io compatible DBML source.
- `payroll_compliance.mmd` - Mermaid ER source.
- `../001_initial_payroll_compliance_schema.sql` - PostgreSQL DDL.
- `../002_seed_payroll_compliance_demo.sql` - demo seed dataset.
- `../example_queries.sql` - operational and validation query examples.

## Suggested usage

1. Apply base schema migration (`001_*`).
2. Apply demo seed migration (`002_*`) in non-production environments.
3. Run `example_queries.sql` to validate relational flow.
