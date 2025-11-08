
-- 03_views_alt.sql
-- Helper functions and reporting views

-- Hourly salary valid at a date d
CREATE OR REPLACE FUNCTION salary_at(emp_id INT, d DATE)
RETURNS NUMERIC
LANGUAGE plpgsql STABLE
AS $body$
DECLARE v_rate NUMERIC;
BEGIN
  SELECT hourly_rate INTO v_rate
  FROM employee_salary
  WHERE employee_id = emp_id
    AND valid_from <= d
    AND (valid_to IS NULL OR d < valid_to)
  ORDER BY valid_from DESC
  LIMIT 1;
  RETURN v_rate;
END;
$body$;

-- Start-date for a (study_year, period_code). P1=Jan1, P2=Apr1, P3=Jul1, P4=Oct1
CREATE OR REPLACE FUNCTION period_start(study_year INT, period_code TEXT)
RETURNS DATE
LANGUAGE plpgsql IMMUTABLE
AS $body$
BEGIN
  IF period_code = 'P1' THEN RETURN make_date(study_year, 1, 1);
  ELSIF period_code = 'P2' THEN RETURN make_date(study_year, 4, 1);
  ELSIF period_code = 'P3' THEN RETURN make_date(study_year, 7, 1);
  ELSIF period_code = 'P4' THEN RETURN make_date(study_year, 10, 1);
  ELSE RAISE EXCEPTION 'Unknown period code: %', period_code;
  END IF;
END;
$body$;

-- Base: planned hours + derived Admin/Exam from coefficients table
CREATE OR REPLACE VIEW v_instance_required_hours AS
WITH base AS (
  SELECT
    ci.instance_id,
    ta.activity_id,
    ta.name AS activity_name,
    pa.planned_hours
  FROM course_instance ci
  JOIN planned_activity pa ON pa.course_instance_id = ci.instance_id
  JOIN teaching_activity ta ON ta.activity_id = pa.activity_id

  UNION ALL
  SELECT
    ci.instance_id,
    ta_ex.activity_id,
    'Examination'::TEXT AS activity_name,
    (c.const + c.hp_coeff * 0 + c.students_coeff * ci.num_students)::NUMERIC(10,2) AS planned_hours
  FROM course_instance ci
  JOIN teaching_activity ta_ex ON ta_ex.name='Examination'
  JOIN derived_activity_coeffs c ON c.activity_id = ta_ex.activity_id

  UNION ALL
  SELECT
    ci.instance_id,
    ta_ad.activity_id,
    'Administration'::TEXT AS activity_name,
    (c.const + c.hp_coeff * clv.hp + c.students_coeff * ci.num_students)::NUMERIC(10,2) AS planned_hours
  FROM course_instance ci
  JOIN course_layout_version clv ON clv.layout_version_id = ci.layout_version_id
  JOIN teaching_activity ta_ad ON ta_ad.name='Administration'
  JOIN derived_activity_coeffs c ON c.activity_id = ta_ad.activity_id
)
SELECT * FROM base;

-- With preparation multipliers applied
CREATE OR REPLACE VIEW v_instance_required_hours_with_prep AS
SELECT
  b.instance_id,
  b.activity_id,
  b.activity_name,
  b.planned_hours,
  (b.planned_hours * ta.factor)::NUMERIC(10,2) AS total_teacher_hours
FROM v_instance_required_hours b
JOIN teaching_activity ta ON ta.activity_id = b.activity_id;

-- Distinct instances per teacher per (year,period)
CREATE OR REPLACE VIEW v_teacher_load_per_period AS
SELECT
  e.employee_id,
  p.first_name || ' ' || p.last_name AS teacher_name,
  ci.study_year,
  sp.code AS study_period_code,
  COUNT(DISTINCT a.course_instance_id) AS distinct_instances
FROM allocation a
JOIN employee e ON e.employee_id = a.employee_id
JOIN person p ON p.person_id = e.person_id
JOIN course_instance ci ON ci.instance_id = a.course_instance_id
JOIN study_period sp ON sp.study_period_id = ci.study_period_id
GROUP BY e.employee_id, teacher_name, ci.study_year, sp.code;

-- Allocation costs using salary valid at period start
CREATE OR REPLACE VIEW v_allocation_costs AS
SELECT
  a.allocation_id,
  a.employee_id,
  p.first_name || ' ' || p.last_name AS teacher_name,
  a.course_instance_id,
  ta.name AS activity_name,
  a.allocated_hours,
  ci.study_year,
  sp.code AS period_code,
  salary_at(a.employee_id, period_start(ci.study_year, sp.code)) AS hourly_rate,
  (a.allocated_hours * salary_at(a.employee_id, period_start(ci.study_year, sp.code)))::NUMERIC(12,2) AS allocation_cost
FROM allocation a
JOIN employee e ON e.employee_id = a.employee_id
JOIN person p ON p.person_id = e.person_id
JOIN teaching_activity ta ON ta.activity_id = a.activity_id
JOIN course_instance ci ON ci.instance_id = a.course_instance_id
JOIN study_period sp ON sp.study_period_id = ci.study_period_id;
