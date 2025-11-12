-- 02b_schema_versioned.sql
-- Versioned model satisfying: (a) all data stored in DB (incl. the '4' limit),
-- (b) ability to keep multiple versions of course layouts and salaries,
-- (c) cost/hours reports that use the correct version per instance/allocation.

BEGIN;

CREATE SCHEMA IF NOT EXISTS dsp;
SET search_path = dsp, public;

-- ===== Reference tables =====

CREATE TABLE study_period (
  code VARCHAR(2) PRIMARY KEY,          -- 'P1' | 'P2' | 'P3' | 'P4'
  quarter_num INT NOT NULL CHECK (quarter_num BETWEEN 1 AND 4)
);

CREATE TABLE job_title (
  job_title VARCHAR(80) PRIMARY KEY
);

-- ===== People / Departments =====

CREATE TABLE person (
  personal_number VARCHAR(32) PRIMARY KEY,
  first_name TEXT NOT NULL,
  last_name  TEXT NOT NULL,
  email      TEXT NOT NULL UNIQUE,
  phone_number TEXT NOT NULL,
  address    TEXT NOT NULL
);

CREATE TABLE department (
  department_id SERIAL PRIMARY KEY,
  department_name TEXT NOT NULL UNIQUE,
  manager_employee_id INT UNIQUE  -- FK added after employee is created
);

CREATE TABLE employee (
  employee_id SERIAL PRIMARY KEY,
  personal_number VARCHAR(32) NOT NULL UNIQUE REFERENCES person(personal_number) ON UPDATE CASCADE ON DELETE RESTRICT,
  department_id INT NOT NULL REFERENCES department(department_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  job_title VARCHAR(80) NOT NULL REFERENCES job_title(job_title) ON UPDATE CASCADE ON DELETE RESTRICT,
  skill_set TEXT NOT NULL,
  supervisor_id INT NULL REFERENCES employee(employee_id) ON UPDATE CASCADE ON DELETE SET NULL
);

ALTER TABLE department
  ADD CONSTRAINT department_manager_fk
  FOREIGN KEY (manager_employee_id) REFERENCES employee(employee_id) ON UPDATE CASCADE ON DELETE SET NULL;

-- ===== Versioned course layout =====

-- Identity of a course (stable attributes)
CREATE TABLE course_layout (
  course_code VARCHAR(16) PRIMARY KEY,
  course_name TEXT NOT NULL
);

-- Versioned attributes of a course layout.
-- We use a simple integer 'version_no'. A new row = a new layout version.
CREATE TABLE course_layout_version (
  layout_version_id SERIAL PRIMARY KEY,
  course_code VARCHAR(16) NOT NULL REFERENCES course_layout(course_code) ON UPDATE CASCADE ON DELETE RESTRICT,
  version_no INT NOT NULL,
  hp NUMERIC(4,1) NOT NULL CHECK (hp > 0),
  min_students INT NOT NULL CHECK (min_students >= 0),
  max_students INT NOT NULL CHECK (max_students >= min_students),
  UNIQUE (course_code, version_no)
);

-- A particular instance of a course in a year/period
CREATE TABLE course_instance (
  instance_id VARCHAR(32) PRIMARY KEY,
  course_code VARCHAR(16) NOT NULL REFERENCES course_layout(course_code) ON UPDATE CASCADE ON DELETE RESTRICT,
  layout_version_no INT NOT NULL,
  study_year  INT NOT NULL CHECK (study_year BETWEEN 2000 AND 2100),
  study_period VARCHAR(2) NOT NULL REFERENCES study_period(code) ON UPDATE CASCADE ON DELETE RESTRICT,
  num_students INT NOT NULL CHECK (num_students >= 0),
  -- Ensure the version used belongs to this course_code
  FOREIGN KEY (course_code, layout_version_no)
    REFERENCES course_layout_version(course_code, version_no) ON UPDATE CASCADE ON DELETE RESTRICT
);

-- ===== Teaching activities =====

CREATE TABLE teaching_activity (
  activity_id SERIAL PRIMARY KEY,
  activity_name TEXT NOT NULL UNIQUE,
  factor NUMERIC(6,2) NOT NULL CHECK (factor > 0),
  is_derived BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE derived_activity_coeffs (
  activity_id INT PRIMARY KEY REFERENCES teaching_activity(activity_id) ON UPDATE CASCADE ON DELETE CASCADE,
  const NUMERIC(12,4) NOT NULL,
  hp_coeff NUMERIC(12,4) NOT NULL,
  students_coeff NUMERIC(12,4) NOT NULL
);

CREATE TABLE planned_activity (
  planned_activity_id SERIAL PRIMARY KEY,
  course_instance_id VARCHAR(32) NOT NULL REFERENCES course_instance(instance_id) ON UPDATE CASCADE ON DELETE CASCADE,
  activity_id INT NOT NULL REFERENCES teaching_activity(activity_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  planned_hours NUMERIC(10,2) NOT NULL CHECK (planned_hours >= 0),
  CONSTRAINT planned_activity_unique UNIQUE (course_instance_id, activity_id)
);

-- ===== Versioned salary =====

CREATE TABLE employee_salary_history (
  salary_version_id SERIAL PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employee(employee_id) ON UPDATE CASCADE ON DELETE CASCADE,
  version_no INT NOT NULL,
  salary_hour NUMERIC(10,2) NOT NULL CHECK (salary_hour > 0),
  UNIQUE (employee_id, version_no)
);

-- Allocations reference the salary version explicitly to guarantee historical correctness
CREATE TABLE allocation (
  allocation_id SERIAL PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employee(employee_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  course_instance_id VARCHAR(32) NOT NULL REFERENCES course_instance(instance_id) ON UPDATE CASCADE ON DELETE CASCADE,
  activity_id INT NOT NULL REFERENCES teaching_activity(activity_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  salary_version_id INT NOT NULL REFERENCES employee_salary_history(salary_version_id) ON UPDATE CASCADE ON DELETE RESTRICT,
  allocated_hours NUMERIC(10,2) NOT NULL CHECK (allocated_hours >= 0),
  CONSTRAINT allocation_unique UNIQUE (employee_id, course_instance_id, activity_id)
);

-- Rule parameter stored IN the DB (do not hardcode '4' in apps)
CREATE TABLE allocation_rule (
  max_instances_per_period INT NOT NULL CHECK (max_instances_per_period >= 1)
);

-- ===== Triggers =====

CREATE OR REPLACE FUNCTION dsp.no_derived_in_planned()
RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT is_derived FROM teaching_activity WHERE activity_id = NEW.activity_id) THEN
    RAISE EXCEPTION 'Do not insert planned_activity for derived activities (activity_id=%). They are computed.', NEW.activity_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_no_derived_in_planned
  BEFORE INSERT OR UPDATE ON planned_activity
  FOR EACH ROW EXECUTE FUNCTION dsp.no_derived_in_planned();

-- Enforce the "≤ max_instances_per_period" rule per employee and period/year
CREATE OR REPLACE FUNCTION dsp.enforce_allocation_limit()
RETURNS TRIGGER AS $$
DECLARE
  lim INT;
  the_period VARCHAR(2);
  the_year INT;
  cnt INT;
BEGIN
  SELECT max_instances_per_period INTO lim FROM allocation_rule LIMIT 1;
  IF lim IS NULL THEN
    lim := 4;
  END IF;

  SELECT ci.study_period, ci.study_year INTO the_period, the_year
  FROM course_instance ci WHERE ci.instance_id = NEW.course_instance_id;

  SELECT COUNT(DISTINCT a.course_instance_id) INTO cnt
  FROM allocation a
  JOIN course_instance ci2 ON ci2.instance_id = a.course_instance_id
  WHERE a.employee_id = NEW.employee_id
    AND ci2.study_period = the_period
    AND ci2.study_year = the_year
    AND (TG_OP <> 'UPDATE' OR a.allocation_id <> NEW.allocation_id);

  IF NOT EXISTS (
      SELECT 1 FROM allocation a2
      WHERE a2.employee_id = NEW.employee_id AND a2.course_instance_id = NEW.course_instance_id
  ) THEN
      cnt := cnt + 1;
  END IF;

  IF cnt > lim THEN
    RAISE EXCEPTION 'Allocation rejected: employee % would exceed % course instances in % %',
      NEW.employee_id, lim, the_period, the_year;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_allocation_limit_ins
  BEFORE INSERT ON allocation
  FOR EACH ROW EXECUTE FUNCTION dsp.enforce_allocation_limit();

CREATE TRIGGER trg_enforce_allocation_limit_upd
  BEFORE UPDATE OF employee_id, course_instance_id ON allocation
  FOR EACH ROW EXECUTE FUNCTION dsp.enforce_allocation_limit();

-- Ensure department manager belongs to department
CREATE OR REPLACE FUNCTION dsp.manager_must_belong_to_department()
RETURNS TRIGGER AS $$
DECLARE emp_dept INT;
BEGIN
  IF NEW.manager_employee_id IS NULL THEN RETURN NEW; END IF;
  SELECT department_id INTO emp_dept FROM employee WHERE employee_id = NEW.manager_employee_id;
  IF emp_dept IS NULL OR emp_dept <> NEW.department_id THEN
    RAISE EXCEPTION 'Manager (employee_id=%) must belong to department_id=%', NEW.manager_employee_id, NEW.department_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_manager_department_consistency
  BEFORE INSERT OR UPDATE OF manager_employee_id, department_id ON department
  FOR EACH ROW EXECUTE FUNCTION dsp.manager_must_belong_to_department();

-- ===== Views =====

-- Effective hours per activity per instance, with versioned HP from the chosen layout version
CREATE OR REPLACE VIEW v_activity_hours AS
WITH base AS (
  SELECT
    pa.course_instance_id,
    pa.activity_id,
    ta.activity_name,
    (pa.planned_hours * ta.factor)::NUMERIC(12,2) AS effective_hours
  FROM planned_activity pa
  JOIN teaching_activity ta ON ta.activity_id = pa.activity_id
  WHERE ta.is_derived = FALSE
),
derived AS (
  SELECT
    ci.instance_id AS course_instance_id,
    ta.activity_id,
    ta.activity_name,
    (c.const + c.hp_coeff * clv.hp + c.students_coeff * ci.num_students)::NUMERIC(12,2) AS effective_hours
  FROM course_instance ci
  JOIN course_layout_version clv ON (clv.course_code = ci.course_code AND clv.version_no = ci.layout_version_no)
  JOIN teaching_activity ta ON ta.is_derived = TRUE
  JOIN derived_activity_coeffs c ON c.activity_id = ta.activity_id
)
SELECT * FROM base
UNION ALL
SELECT * FROM derived;

-- Course instance header info including course name via course_layout
CREATE OR REPLACE VIEW v_course_instance_header AS
SELECT
  ci.instance_id,
  ci.course_code,
  cl.course_name,
  ci.study_year,
  ci.study_period,
  ci.num_students,
  ci.layout_version_no,
  clv.hp, clv.min_students, clv.max_students
FROM course_instance ci
JOIN course_layout cl ON cl.course_code = ci.course_code
JOIN course_layout_version clv ON (clv.course_code = ci.course_code AND clv.version_no = ci.layout_version_no);

CREATE OR REPLACE VIEW v_course_instance_total_hours AS
SELECT
  h.instance_id,
  h.course_code,
  h.course_name,
  h.study_year,
  h.study_period,
  SUM(v.effective_hours)::NUMERIC(12,2) AS total_effective_hours
FROM v_course_instance_header h
JOIN v_activity_hours v ON v.course_instance_id = h.instance_id
GROUP BY h.instance_id, h.course_code, h.course_name, h.study_year, h.study_period;

-- Cost per allocation, using the salary version stored on the allocation
CREATE OR REPLACE VIEW v_allocation_cost AS
SELECT
  a.allocation_id,
  a.employee_id,
  a.course_instance_id,
  a.activity_id,
  s.salary_hour,
  (a.allocated_hours * s.salary_hour)::NUMERIC(12,2) AS cost
FROM allocation a
JOIN employee_salary_history s ON s.salary_version_id = a.salary_version_id;

CREATE OR REPLACE VIEW v_course_instance_cost AS
SELECT
  ci.instance_id,
  SUM(v.cost)::NUMERIC(12,2) AS total_cost
FROM v_allocation_cost v
JOIN course_instance ci ON ci.instance_id = v.course_instance_id
GROUP BY ci.instance_id;

CREATE OR REPLACE VIEW v_department_cost_by_period AS
SELECT
  d.department_id,
  d.department_name,
  ci.study_year,
  ci.study_period,
  SUM(v.cost)::NUMERIC(12,2) AS total_cost
FROM v_allocation_cost v
JOIN allocation a ON a.allocation_id = v.allocation_id
JOIN employee e ON e.employee_id = a.employee_id
JOIN department d ON d.department_id = e.department_id
JOIN course_instance ci ON ci.instance_id = v.course_instance_id
GROUP BY d.department_id, d.department_name, ci.study_year, ci.study_period;

COMMIT;
