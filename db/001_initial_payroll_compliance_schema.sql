BEGIN;

-- =========================================================
-- 1) ENUM TYPES
-- =========================================================
CREATE TYPE status_generic AS ENUM ('draft', 'active', 'inactive', 'terminated', 'suspended', 'closed');
CREATE TYPE verification_status AS ENUM ('pending', 'verified', 'rejected', 'expired');
CREATE TYPE approval_status AS ENUM ('draft', 'in_review', 'approved', 'rejected', 'deprecated');
CREATE TYPE risk_level AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE control_severity AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE payroll_run_type AS ENUM ('regular', 'offcycle', 'correction', 'final');
CREATE TYPE decision_result_code AS ENUM ('pass', 'fail', 'warning', 'not_applicable', 'error');
CREATE TYPE actor_type AS ENUM ('system', 'user', 'service', 'external');

-- =========================================================
-- 2) CORE TENANCY / MASTER DATA
-- =========================================================
CREATE TABLE tenant (
    tenant_id uuid PRIMARY KEY,
    name text NOT NULL,
    timezone text NOT NULL,
    status status_generic NOT NULL DEFAULT 'active'
);

CREATE TABLE legal_entity (
    legal_entity_id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES tenant(tenant_id),
    name text NOT NULL,
    kvk_number text,
    entity_type text NOT NULL,
    active_from date NOT NULL,
    active_to date,
    CONSTRAINT chk_legal_entity_active_range CHECK (active_to IS NULL OR active_to >= active_from)
);

CREATE TABLE client (
    client_id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES tenant(tenant_id),
    legal_entity_id uuid REFERENCES legal_entity(legal_entity_id),
    client_code text NOT NULL,
    name text NOT NULL,
    cao_name text,
    cao_version text,
    status status_generic NOT NULL DEFAULT 'active',
    CONSTRAINT uq_client_code_per_tenant UNIQUE (tenant_id, client_code)
);

CREATE TABLE client_site (
    site_id uuid PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES client(client_id),
    name text NOT NULL,
    cost_center_code text,
    status status_generic NOT NULL DEFAULT 'active',
    CONSTRAINT uq_site_cost_center_per_client UNIQUE (client_id, cost_center_code)
);

CREATE TABLE worker (
    worker_id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES tenant(tenant_id),
    worker_no text NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    birth_date date,
    bsn_token text,
    status status_generic NOT NULL DEFAULT 'active',
    CONSTRAINT uq_worker_no_per_tenant UNIQUE (tenant_id, worker_no)
);

CREATE TABLE employment_contract (
    contract_id uuid PRIMARY KEY,
    worker_id uuid NOT NULL REFERENCES worker(worker_id),
    legal_entity_id uuid NOT NULL REFERENCES legal_entity(legal_entity_id),
    contract_regime text,
    contract_form text,
    start_date date NOT NULL,
    end_date date,
    status status_generic NOT NULL DEFAULT 'active',
    CONSTRAINT chk_employment_contract_range CHECK (end_date IS NULL OR end_date >= start_date)
);

-- =========================================================
-- 3) JOB / PACKAGE DEFINITIONS
-- =========================================================
CREATE TABLE client_job_profile (
    client_job_profile_id uuid PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES client(client_id),
    job_code_client text NOT NULL,
    title text NOT NULL,
    job_family text,
    job_level text,
    effective_from date NOT NULL,
    effective_to date,
    CONSTRAINT chk_client_job_profile_range CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT uq_client_job_code UNIQUE (client_id, job_code_client, effective_from)
);

CREATE TABLE comparator_profile (
    comparator_profile_id uuid PRIMARY KEY,
    client_job_profile_id uuid NOT NULL UNIQUE REFERENCES client_job_profile(client_job_profile_id),
    comparable_role_title text NOT NULL,
    internal_scale_code text,
    step_code text,
    normal_hours_per_week numeric(7,2),
    source_document_ref text,
    CONSTRAINT chk_comparator_hours CHECK (normal_hours_per_week IS NULL OR normal_hours_per_week > 0)
);

CREATE TABLE client_package (
    client_package_id uuid PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES client(client_id),
    client_job_profile_id uuid NOT NULL REFERENCES client_job_profile(client_job_profile_id),
    package_name text NOT NULL,
    source_type text NOT NULL,
    effective_from date NOT NULL,
    effective_to date,
    verification_status verification_status NOT NULL DEFAULT 'pending',
    CONSTRAINT chk_client_package_range CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

CREATE TABLE compensation_component_type (
    component_type_id uuid PRIMARY KEY,
    code text NOT NULL UNIQUE,
    name text NOT NULL,
    category text NOT NULL,
    valuation_method text NOT NULL
);

CREATE TABLE client_package_component (
    package_component_id uuid PRIMARY KEY,
    client_package_id uuid NOT NULL REFERENCES client_package(client_package_id),
    component_type_id uuid NOT NULL REFERENCES compensation_component_type(component_type_id),
    component_code text NOT NULL,
    value_type text NOT NULL,
    value_amount numeric(14,4),
    value_percent numeric(8,4),
    unit_code text,
    effective_from date NOT NULL,
    effective_to date,
    CONSTRAINT chk_client_pkg_component_range CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT chk_client_pkg_component_value CHECK (
        (value_amount IS NOT NULL)::int + (value_percent IS NOT NULL)::int = 1
    )
);

-- =========================================================
-- 4) ASSIGNMENTS / TIMESHEETS / PAY PACKAGE
-- =========================================================
CREATE TABLE assignment (
    assignment_id uuid PRIMARY KEY,
    worker_id uuid NOT NULL REFERENCES worker(worker_id),
    client_id uuid NOT NULL REFERENCES client(client_id),
    site_id uuid REFERENCES client_site(site_id),
    contract_id uuid REFERENCES employment_contract(contract_id),
    supplier_entity_id uuid REFERENCES legal_entity(legal_entity_id),
    job_profile_id uuid REFERENCES client_job_profile(client_job_profile_id),
    start_date date NOT NULL,
    end_date date,
    planned_hours_per_week numeric(7,2),
    status status_generic NOT NULL DEFAULT 'active',
    CONSTRAINT chk_assignment_range CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_assignment_hours CHECK (planned_hours_per_week IS NULL OR planned_hours_per_week > 0)
);

CREATE TABLE assignment_terms_snapshot (
    snapshot_id uuid PRIMARY KEY,
    assignment_id uuid NOT NULL REFERENCES assignment(assignment_id),
    snapshot_version integer NOT NULL,
    captured_at timestamptz NOT NULL,
    job_profile_payload jsonb NOT NULL,
    client_package_payload jsonb NOT NULL,
    derived_pay_package_payload jsonb NOT NULL,
    hash_value text NOT NULL,
    CONSTRAINT uq_assignment_snapshot_version UNIQUE (assignment_id, snapshot_version)
);

CREATE TABLE worker_pay_package (
    worker_pay_package_id uuid PRIMARY KEY,
    assignment_id uuid NOT NULL REFERENCES assignment(assignment_id),
    client_package_id uuid REFERENCES client_package(client_package_id),
    required_total_value numeric(14,4) NOT NULL,
    actual_total_value numeric(14,4) NOT NULL,
    gap_value numeric(14,4) NOT NULL,
    equalization_method text,
    status status_generic NOT NULL DEFAULT 'active',
    calculated_at timestamptz NOT NULL
);

CREATE TABLE worker_pay_package_component (
    worker_pkg_component_id uuid PRIMARY KEY,
    worker_pay_package_id uuid NOT NULL REFERENCES worker_pay_package(worker_pay_package_id),
    component_type_id uuid NOT NULL REFERENCES compensation_component_type(component_type_id),
    required_value numeric(14,4) NOT NULL,
    actual_value numeric(14,4) NOT NULL,
    gap_value numeric(14,4) NOT NULL,
    resolution_action text,
    status status_generic NOT NULL DEFAULT 'active'
);

CREATE TABLE timesheet (
    timesheet_id uuid PRIMARY KEY,
    assignment_id uuid NOT NULL REFERENCES assignment(assignment_id),
    period_start date NOT NULL,
    period_end date NOT NULL,
    status status_generic NOT NULL DEFAULT 'draft',
    submitted_at timestamptz,
    approved_at timestamptz,
    CONSTRAINT chk_timesheet_period CHECK (period_end >= period_start),
    CONSTRAINT chk_timesheet_approval_order CHECK (approved_at IS NULL OR submitted_at IS NULL OR approved_at >= submitted_at),
    CONSTRAINT uq_timesheet_assignment_period UNIQUE (assignment_id, period_start, period_end)
);

CREATE TABLE time_entry (
    time_entry_id uuid PRIMARY KEY,
    timesheet_id uuid NOT NULL REFERENCES timesheet(timesheet_id),
    work_date date NOT NULL,
    hours_worked numeric(7,2) NOT NULL,
    hours_type text NOT NULL,
    start_time timestamptz,
    end_time timestamptz,
    CONSTRAINT chk_time_entry_hours CHECK (hours_worked > 0 AND hours_worked <= 24),
    CONSTRAINT chk_time_entry_clock_order CHECK (end_time IS NULL OR start_time IS NULL OR end_time > start_time)
);

-- =========================================================
-- 5) PAYROLL
-- =========================================================
CREATE TABLE payroll_period (
    payroll_period_id uuid PRIMARY KEY,
    tenant_id uuid NOT NULL REFERENCES tenant(tenant_id),
    period_code text NOT NULL,
    date_from date NOT NULL,
    date_to date NOT NULL,
    pay_date date NOT NULL,
    status status_generic NOT NULL DEFAULT 'draft',
    CONSTRAINT chk_payroll_period_dates CHECK (date_to >= date_from),
    CONSTRAINT uq_period_code_per_tenant UNIQUE (tenant_id, period_code)
);

CREATE TABLE payroll_run (
    payroll_run_id uuid PRIMARY KEY,
    payroll_period_id uuid NOT NULL REFERENCES payroll_period(payroll_period_id),
    run_type payroll_run_type NOT NULL,
    status status_generic NOT NULL DEFAULT 'draft',
    started_at timestamptz,
    completed_at timestamptz,
    CONSTRAINT chk_payroll_run_time_order CHECK (completed_at IS NULL OR started_at IS NULL OR completed_at >= started_at)
);

CREATE TABLE payroll_result (
    payroll_result_id uuid PRIMARY KEY,
    assignment_id uuid NOT NULL REFERENCES assignment(assignment_id),
    payroll_run_id uuid NOT NULL REFERENCES payroll_run(payroll_run_id),
    gross_amount numeric(14,4) NOT NULL,
    net_amount numeric(14,4) NOT NULL,
    employer_cost numeric(14,4) NOT NULL,
    result_status status_generic NOT NULL DEFAULT 'active'
);

CREATE TABLE pay_line (
    pay_line_id uuid PRIMARY KEY,
    payroll_result_id uuid NOT NULL REFERENCES payroll_result(payroll_result_id),
    line_type text NOT NULL,
    component_code text NOT NULL,
    quantity numeric(12,4),
    rate numeric(14,6),
    amount numeric(14,4) NOT NULL,
    explanation_ref text
);

-- =========================================================
-- 6) LEGAL / CONTROLS / RULES
-- =========================================================
CREATE TABLE legal_source (
    legal_source_id uuid PRIMARY KEY,
    source_type text NOT NULL,
    title text NOT NULL,
    publisher text,
    source_url text,
    document_hash text,
    published_at timestamptz,
    effective_from date,
    effective_to date,
    CONSTRAINT chk_legal_source_effective_range CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

CREATE TABLE legal_obligation (
    obligation_id uuid PRIMARY KEY,
    legal_source_id uuid NOT NULL REFERENCES legal_source(legal_source_id),
    article_ref text,
    obligation_code text NOT NULL,
    subject_type text,
    obligation_text text NOT NULL,
    risk_level risk_level NOT NULL,
    effective_from date,
    effective_to date,
    CONSTRAINT chk_legal_obligation_range CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

CREATE TABLE control_definition (
    control_id uuid PRIMARY KEY,
    obligation_id uuid NOT NULL REFERENCES legal_obligation(obligation_id),
    control_code text NOT NULL UNIQUE,
    control_name text NOT NULL,
    control_type text NOT NULL,
    severity control_severity NOT NULL,
    execution_phase text NOT NULL
);

CREATE TABLE rule_set (
    rule_set_id uuid PRIMARY KEY,
    domain_code text NOT NULL,
    name text NOT NULL,
    status status_generic NOT NULL DEFAULT 'draft'
);

CREATE TABLE rule_version (
    rule_version_id uuid PRIMARY KEY,
    rule_set_id uuid NOT NULL REFERENCES rule_set(rule_set_id),
    control_id uuid NOT NULL REFERENCES control_definition(control_id),
    version_no integer NOT NULL,
    dsl_expression text,
    decision_table_ref text,
    effective_from date,
    effective_to date,
    published_at timestamptz,
    approval_status approval_status NOT NULL DEFAULT 'draft',
    CONSTRAINT uq_rule_version UNIQUE (rule_set_id, version_no),
    CONSTRAINT chk_rule_version_range CHECK (effective_to IS NULL OR effective_from IS NULL OR effective_to >= effective_from)
);

CREATE TABLE decision_execution (
    decision_execution_id uuid PRIMARY KEY,
    rule_version_id uuid NOT NULL REFERENCES rule_version(rule_version_id),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    execution_phase text NOT NULL,
    input_payload jsonb NOT NULL,
    output_payload jsonb,
    result_code decision_result_code NOT NULL,
    severity control_severity,
    executed_at timestamptz NOT NULL,
    trace_id text
);

CREATE TABLE decision_exception (
    exception_id uuid PRIMARY KEY,
    decision_execution_id uuid NOT NULL REFERENCES decision_execution(decision_execution_id),
    exception_type text NOT NULL,
    reason_code text,
    requested_by text,
    approved_by text,
    expires_at timestamptz,
    status status_generic NOT NULL DEFAULT 'active'
);

-- =========================================================
-- 7) WTTA / REGISTERS / REMEDIATION / AUDIT
-- =========================================================
CREATE TABLE wtta_subject (
    wtta_subject_id uuid PRIMARY KEY,
    legal_entity_id uuid NOT NULL REFERENCES legal_entity(legal_entity_id),
    subject_role text NOT NULL,
    nau_identifier text,
    is_public_register_match boolean NOT NULL DEFAULT false,
    status status_generic NOT NULL DEFAULT 'active'
);

CREATE TABLE wtta_status_history (
    status_history_id uuid PRIMARY KEY,
    wtta_subject_id uuid NOT NULL REFERENCES wtta_subject(wtta_subject_id),
    status_code text NOT NULL,
    status_reason text,
    valid_from date NOT NULL,
    valid_to date,
    source_ref text,
    CONSTRAINT chk_wtta_status_range CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

CREATE TABLE inlener_borrowed_worker_register (
    register_record_id uuid PRIMARY KEY,
    client_id uuid NOT NULL REFERENCES client(client_id),
    assignment_id uuid NOT NULL REFERENCES assignment(assignment_id),
    worker_id uuid NOT NULL REFERENCES worker(worker_id),
    supplier_entity_id uuid REFERENCES legal_entity(legal_entity_id),
    borrowed_from_date date NOT NULL,
    borrowed_to_date date,
    record_status status_generic NOT NULL DEFAULT 'active',
    CONSTRAINT chk_inlener_range CHECK (borrowed_to_date IS NULL OR borrowed_to_date >= borrowed_from_date)
);

CREATE TABLE remediation_case (
    case_id uuid PRIMARY KEY,
    decision_execution_id uuid NOT NULL REFERENCES decision_execution(decision_execution_id),
    case_type text NOT NULL,
    priority text,
    owner_user_id text,
    opened_at timestamptz NOT NULL,
    due_at timestamptz,
    status status_generic NOT NULL DEFAULT 'active',
    CONSTRAINT chk_remediation_due CHECK (due_at IS NULL OR due_at >= opened_at)
);

CREATE TABLE audit_event (
    audit_event_id uuid PRIMARY KEY,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    event_type text NOT NULL,
    event_payload jsonb,
    occurred_at timestamptz NOT NULL,
    actor_type actor_type NOT NULL,
    actor_id text,
    trace_id text
);

-- =========================================================
-- 8) INDEXES
-- =========================================================
CREATE INDEX idx_legal_entity_tenant_id ON legal_entity (tenant_id);
CREATE INDEX idx_client_tenant_id ON client (tenant_id);
CREATE INDEX idx_worker_tenant_id ON worker (tenant_id);

CREATE INDEX idx_assignment_worker_id ON assignment (worker_id);
CREATE INDEX idx_assignment_client_id ON assignment (client_id);
CREATE INDEX idx_assignment_contract_id ON assignment (contract_id);
CREATE INDEX idx_assignment_job_profile_id ON assignment (job_profile_id);
CREATE INDEX idx_assignment_start_end ON assignment (start_date, end_date);

CREATE INDEX idx_timesheet_assignment_id ON timesheet (assignment_id);
CREATE INDEX idx_time_entry_timesheet_id ON time_entry (timesheet_id);
CREATE INDEX idx_time_entry_work_date ON time_entry (work_date);

CREATE INDEX idx_payroll_period_tenant_id ON payroll_period (tenant_id);
CREATE INDEX idx_payroll_run_period_id ON payroll_run (payroll_period_id);
CREATE INDEX idx_payroll_result_run_id ON payroll_result (payroll_run_id);
CREATE INDEX idx_payroll_result_assignment_id ON payroll_result (assignment_id);
CREATE INDEX idx_pay_line_result_id ON pay_line (payroll_result_id);

CREATE INDEX idx_rule_version_rule_set_id ON rule_version (rule_set_id);
CREATE INDEX idx_rule_version_control_id ON rule_version (control_id);
CREATE INDEX idx_decision_execution_rule_version_id ON decision_execution (rule_version_id);
CREATE INDEX idx_decision_execution_entity ON decision_execution (entity_type, entity_id);
CREATE INDEX idx_decision_execution_trace ON decision_execution (trace_id);
CREATE INDEX idx_decision_exception_execution_id ON decision_exception (decision_execution_id);

CREATE INDEX idx_remediation_case_execution_id ON remediation_case (decision_execution_id);
CREATE INDEX idx_wtta_subject_legal_entity_id ON wtta_subject (legal_entity_id);
CREATE INDEX idx_wtta_status_history_subject_id ON wtta_status_history (wtta_subject_id);
CREATE INDEX idx_inlener_assignment_id ON inlener_borrowed_worker_register (assignment_id);
CREATE INDEX idx_audit_event_entity ON audit_event (entity_type, entity_id);
CREATE INDEX idx_audit_event_trace ON audit_event (trace_id);

-- GIN indexes for JSON payload analytics/inspection.
CREATE INDEX idx_assignment_terms_snapshot_job_payload_gin
    ON assignment_terms_snapshot USING GIN (job_profile_payload);
CREATE INDEX idx_decision_execution_input_payload_gin
    ON decision_execution USING GIN (input_payload);

COMMIT;
