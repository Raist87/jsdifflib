# Migration order

Apply migrations in this order:

1. Create enum types.
2. Create core tenancy/master data tables:
   - `tenant`, `legal_entity`, `client`, `client_site`, `worker`, `employment_contract`
3. Create job/package definition tables:
   - `client_job_profile`, `comparator_profile`, `client_package`, `compensation_component_type`, `client_package_component`
4. Create assignment/time/pay-package tables:
   - `assignment`, `assignment_terms_snapshot`, `worker_pay_package`, `worker_pay_package_component`, `timesheet`, `time_entry`
5. Create payroll tables:
   - `payroll_period`, `payroll_run`, `payroll_result`, `pay_line`
6. Create legal/control/rule tables:
   - `legal_source`, `legal_obligation`, `control_definition`, `rule_set`, `rule_version`, `decision_execution`, `decision_exception`
7. Create WTTA/register/remediation/audit tables:
   - `wtta_subject`, `wtta_status_history`, `inlener_borrowed_worker_register`, `remediation_case`, `audit_event`
8. Apply temporal hardening constraints (GiST exclusion constraints).
9. Create indexes (BTREE + GIN).
10. (Optional, non-production) Apply demo seed migration:
   - `002_seed_payroll_compliance_demo.sql`

Because all objects are included in `db/001_initial_payroll_compliance_schema.sql`, this ordering is encoded directly in that file.
