BEGIN;

-- Tenant + entities
INSERT INTO tenant (tenant_id, name, timezone, status)
VALUES ('00000000-0000-0000-0000-000000000001', 'Acme Staffing NL', 'Europe/Amsterdam', 'active');

INSERT INTO legal_entity (legal_entity_id, tenant_id, name, kvk_number, entity_type, active_from, active_to)
VALUES
('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000001', 'Acme Staffing B.V.', '12345678', 'supplier', '2020-01-01', NULL),
('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-000000000001', 'Client Holding B.V.', '87654321', 'client_owner', '2020-01-01', NULL);

INSERT INTO client (client_id, tenant_id, legal_entity_id, client_code, name, cao_name, cao_version, status)
VALUES ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000102', 'CL-001', 'Retail Client NL', 'ABU CAO', '2025', 'active');

INSERT INTO client_site (site_id, client_id, name, cost_center_code, status)
VALUES ('00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000201', 'Utrecht DC', 'UTR-DC', 'active');

INSERT INTO worker (worker_id, tenant_id, worker_no, first_name, last_name, birth_date, bsn_token, status)
VALUES ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000001', 'W-1001', 'Sam', 'Jansen', '1995-03-14', 'tok_bsn_1001', 'active');

INSERT INTO employment_contract (contract_id, worker_id, legal_entity_id, contract_regime, contract_form, start_date, end_date, status)
VALUES ('00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000101', 'phase_b', 'temporary', '2025-01-01', NULL, 'active');

-- Job/profile/package
INSERT INTO client_job_profile (client_job_profile_id, client_id, job_code_client, title, job_family, job_level, effective_from, effective_to)
VALUES ('00000000-0000-0000-0000-000000000601', '00000000-0000-0000-0000-000000000201', 'WH-OP-1', 'Warehouse Operator', 'Operations', 'L1', '2025-01-01', NULL);

INSERT INTO comparator_profile (comparator_profile_id, client_job_profile_id, comparable_role_title, internal_scale_code, step_code, normal_hours_per_week, source_document_ref)
VALUES ('00000000-0000-0000-0000-000000000602', '00000000-0000-0000-0000-000000000601', 'Warehouse Operator', 'SCALE-A', 'STEP-1', 40.00, 'cao://abu/2025/art-15');

INSERT INTO client_package (client_package_id, client_id, client_job_profile_id, package_name, source_type, effective_from, effective_to, verification_status)
VALUES ('00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000601', 'Warehouse Standard 2025', 'cao', '2025-01-01', NULL, 'verified');

INSERT INTO compensation_component_type (component_type_id, code, name, category, valuation_method)
VALUES
('00000000-0000-0000-0000-000000000801', 'BASE', 'Base Hourly Wage', 'cash', 'hourly_rate'),
('00000000-0000-0000-0000-000000000802', 'HOL', 'Holiday Allowance', 'cash', 'percentage');

INSERT INTO client_package_component (package_component_id, client_package_id, component_type_id, component_code, value_type, value_amount, value_percent, unit_code, effective_from, effective_to)
VALUES
('00000000-0000-0000-0000-000000000901', '00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000801', 'BASE', 'amount', 18.5000, NULL, 'EUR_PER_HOUR', '2025-01-01', NULL),
('00000000-0000-0000-0000-000000000902', '00000000-0000-0000-0000-000000000701', '00000000-0000-0000-0000-000000000802', 'HOL', 'percent', NULL, 8.3300, 'PERCENT', '2025-01-01', NULL);

-- Assignment + time + payroll
INSERT INTO assignment (assignment_id, worker_id, client_id, site_id, contract_id, supplier_legal_entity_id, client_job_profile_id, start_date, end_date, planned_hours_per_week, status)
VALUES ('00000000-0000-0000-0000-000000001001', '00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000301', '00000000-0000-0000-0000-000000000501', '00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000601', '2025-01-06', NULL, 40.00, 'active');

INSERT INTO timesheet (timesheet_id, assignment_id, period_start, period_end, status, submitted_at, approved_at)
VALUES ('00000000-0000-0000-0000-000000001101', '00000000-0000-0000-0000-000000001001', '2025-01-06', '2025-01-12', 'active', '2025-01-13T08:00:00Z', '2025-01-13T10:00:00Z');

INSERT INTO time_entry (time_entry_id, timesheet_id, work_date, hours_worked, hours_type, start_time, end_time)
VALUES
('00000000-0000-0000-0000-000000001201', '00000000-0000-0000-0000-000000001101', '2025-01-06', 8.00, 'regular', '2025-01-06T08:00:00Z', '2025-01-06T16:00:00Z'),
('00000000-0000-0000-0000-000000001202', '00000000-0000-0000-0000-000000001101', '2025-01-07', 8.00, 'regular', '2025-01-07T08:00:00Z', '2025-01-07T16:00:00Z');

INSERT INTO payroll_period (payroll_period_id, tenant_id, period_code, date_from, date_to, pay_date, status)
VALUES ('00000000-0000-0000-0000-000000001301', '00000000-0000-0000-0000-000000000001', '2025-W02', '2025-01-06', '2025-01-12', '2025-01-15', 'active');

INSERT INTO payroll_run (payroll_run_id, payroll_period_id, run_type, status, started_at, completed_at)
VALUES ('00000000-0000-0000-0000-000000001401', '00000000-0000-0000-0000-000000001301', 'regular', 'active', '2025-01-14T06:00:00Z', '2025-01-14T06:30:00Z');

INSERT INTO payroll_result (payroll_result_id, assignment_id, payroll_run_id, gross_amount, net_amount, employer_cost, result_status)
VALUES ('00000000-0000-0000-0000-000000001501', '00000000-0000-0000-0000-000000001001', '00000000-0000-0000-0000-000000001401', 740.00, 592.00, 815.00, 'active');

INSERT INTO pay_line (pay_line_id, payroll_result_id, line_type, component_code, quantity, rate, amount, explanation_ref)
VALUES
('00000000-0000-0000-0000-000000001601', '00000000-0000-0000-0000-000000001501', 'earning', 'BASE', 40.0000, 18.500000, 740.0000, 'calc://base-hours'),
('00000000-0000-0000-0000-000000001602', '00000000-0000-0000-0000-000000001501', 'deduction', 'TAX', NULL, NULL, -148.0000, 'calc://withholding');

COMMIT;
