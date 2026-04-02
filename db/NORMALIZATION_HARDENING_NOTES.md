# Schema normalization and hardening notes

## Implemented fixes

1. **Naming consistency for legal entity references**
   - Renamed `assignment.supplier_entity_id` -> `assignment.supplier_legal_entity_id`.
   - Renamed `inlener_borrowed_worker_register.supplier_entity_id` -> `inlener_borrowed_worker_register.supplier_legal_entity_id`.
   - Rationale: all legal entity FKs now explicitly carry `_legal_entity_id` suffix.

2. **Naming consistency for job profile references**
   - Renamed `assignment.job_profile_id` -> `assignment.client_job_profile_id`.
   - Rationale: FK target table is `client_job_profile`, so column naming now matches semantic ownership.

3. **Nullable FK hardening (minimum required relations)**
   - Made `assignment.supplier_legal_entity_id` `NOT NULL`.
   - Made `assignment.client_job_profile_id` `NOT NULL`.
   - Made `inlener_borrowed_worker_register.supplier_legal_entity_id` `NOT NULL`.
   - Rationale: these are required to support compliance traceability and equal-pay comparability.

4. **Temporal integrity hardening (prevent overlaps)**
   - Added GiST exclusion constraints to prevent overlapping ranges for:
     - `employment_contract` by `(worker_id, legal_entity_id)`
     - `assignment` by `(worker_id, client_id)`
     - `client_job_profile` by `(client_id, job_code_client)`
     - `client_package` by `(client_id, package_name)`
   - Added `btree_gist` extension required for mixed equality + range exclusion semantics.

5. **Index updates after normalization**
   - Replaced assignment index on old job profile FK with `client_job_profile_id`.
   - Added indexes for `supplier_legal_entity_id` in assignment and borrowed-worker register tables.

## Additional proposed fixes (recommended next migration)

1. **Tenant isolation by construction**
   - Add `tenant_id` to all transactional tables.
   - Convert selected FKs to composite `(tenant_id, <id>)` references to block cross-tenant links.

2. **Status code governance refinement**
   - Replace broad `status_generic` usage with per-aggregate enums, e.g.:
     - `assignment_status`, `timesheet_status`, `payroll_run_status`, `remediation_case_status`.
   - This avoids invalid lifecycle values being accepted by unrelated tables.

3. **System-versioned history for high-risk entities**
   - Add immutable history tables for `assignment`, `worker_pay_package`, and `rule_version` changes.
   - Link revisions to `audit_event.trace_id` for complete forensic lineage.

4. **Deferrable cross-table validity checks**
   - Add trigger-based checks to ensure:
     - `time_entry.work_date` is within assignment active dates.
     - `timesheet` periods align to payroll period boundaries.
     - `assignment.contract_id` worker matches `assignment.worker_id`.

