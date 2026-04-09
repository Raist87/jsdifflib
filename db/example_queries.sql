-- 1) Active assignments with worker + client + profile + package.
SELECT
    a.assignment_id,
    w.worker_no,
    w.first_name,
    w.last_name,
    c.client_code,
    c.name AS client_name,
    cjp.job_code_client,
    cjp.title,
    cp.package_name,
    a.planned_hours_per_week
FROM assignment a
JOIN worker w ON w.worker_id = a.worker_id
JOIN client c ON c.client_id = a.client_id
JOIN client_job_profile cjp ON cjp.client_job_profile_id = a.client_job_profile_id
LEFT JOIN client_package cp
  ON cp.client_job_profile_id = cjp.client_job_profile_id
 AND cp.effective_to IS NULL
WHERE a.status = 'active';

-- 2) Weekly submitted hours per assignment.
SELECT
    t.assignment_id,
    t.period_start,
    t.period_end,
    SUM(te.hours_worked) AS total_hours
FROM timesheet t
JOIN time_entry te ON te.timesheet_id = t.timesheet_id
GROUP BY t.assignment_id, t.period_start, t.period_end
ORDER BY t.period_start;

-- 3) Equal-pay component view from client package.
SELECT
    cp.client_package_id,
    cp.package_name,
    cct.code AS component_code,
    cct.name AS component_name,
    cpc.value_amount,
    cpc.value_percent,
    cpc.unit_code
FROM client_package cp
JOIN client_package_component cpc ON cpc.client_package_id = cp.client_package_id
JOIN compensation_component_type cct ON cct.component_type_id = cpc.component_type_id
ORDER BY cp.package_name, cct.code;

-- 4) Payroll result with pay line breakdown.
SELECT
    pr.payroll_result_id,
    pr.assignment_id,
    pr.gross_amount,
    pr.net_amount,
    pr.employer_cost,
    pl.line_type,
    pl.component_code,
    pl.amount
FROM payroll_result pr
JOIN pay_line pl ON pl.payroll_result_id = pr.payroll_result_id
ORDER BY pr.payroll_result_id, pl.component_code;

-- 5) Detect overlapping assignments (should be empty due to exclusion constraint).
SELECT a1.assignment_id AS assignment_a, a2.assignment_id AS assignment_b
FROM assignment a1
JOIN assignment a2
  ON a1.worker_id = a2.worker_id
 AND a1.client_id = a2.client_id
 AND a1.assignment_id < a2.assignment_id
 AND daterange(a1.start_date, COALESCE(a1.end_date, 'infinity'::date), '[]')
     && daterange(a2.start_date, COALESCE(a2.end_date, 'infinity'::date), '[]');
