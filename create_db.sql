
-- 01_schema_alt.sql
-- Safer schema for Course Layout & Teaching Load Allocations (PostgreSQL 14+)
-- - No BEGIN/COMMIT wrapper
-- - No DO $$ anonymous block
-- - No subquery in CHECK constraints (use trigger instead)

-- Drop views if re-running (ignore if they don't exist)
DROP VIEW IF EXISTS v_instance_required_hours CASCADE;
DROP VIEW IF EXISTS v_instance_required_hours_with_prep CASCADE;
DROP VIEW IF EXISTS v_allocation_costs CASCADE;
DROP VIEW IF EXISTS v_teacher_load_per_period CASCADE;

-- Drop tables in dependency order
DROP TABLE IF EXISTS allocation CASCADE;
DROP TABLE IF EXISTS planned_activity CASCADE;
DROP TABLE IF EXISTS course_instance CASCADE;
DROP TABLE IF EXISTS course_layout_version CASCADE;
DROP TABLE IF EXISTS course CASCADE;
DROP TABLE IF EXISTS study_period CASCADE;
DROP TABLE IF EXISTS teaching_activity CASCADE;
DROP TABLE IF EXISTS employee_salary CASCADE;
DROP TABLE IF EXISTS employee CASCADE;
DROP TABLE IF EXISTS job_title CASCADE;
DROP TABLE IF EXISTS department CASCADE;
DROP TABLE IF EXISTS person CASCADE;
DROP TABLE IF EXISTS allocation_rule CASCADE;
DROP TABLE IF EXISTS derived_activity_coeffs CASCADE;

-- Lookup tables and base entities

CREATE TABLE study_period (
  study_period_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code TEXT UNIQUE NOT NULL CHECK (code IN ('P1','P2','P3','P4')),
  quarter_num INT NOT NULL CHECK (quarter_num BETWEEN 1 AND 4)
);

CREATE TABLE teaching_activity (
  activity_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT UNIQUE NOT NULL,
  factor NUMERIC(4,2) NOT NULL DEFAULT 1.00,
  is_derived BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE person (
  person_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  personal_number TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  phone_number TEXT NOT NULL,
  address TEXT NOT NULL
);

CREATE TABLE job_title (
  job_title_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

CREATE TABLE department (
  department_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  department_name TEXT UNIQUE NOT NULL,
  manager_employee_id INT
);

CREATE TABLE employee (
  employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  person_id INT NOT NULL REFERENCES person(person_id) ON DELETE CASCADE,
  department_id INT NOT NULL REFERENCES department(department_id),
  job_title_id INT NOT NULL REFERENCES job_title(job_title_id),
  skill_set TEXT NOT NULL,
  supervisor_employee_id INT,
  CONSTRAINT uq_employee_person UNIQUE(person_id)
);

ALTER TABLE employee
  ADD CONSTRAINT fk_employee_supervisor
  FOREIGN KEY (supervisor_employee_id) REFERENCES employee(employee_id) DEFERRABLE INITIALLY DEFERRED;

ALTER TABLE department
  ADD CONSTRAINT fk_department_manager
  FOREIGN KEY (manager_employee_id) REFERENCES employee(employee_id) DEFERRABLE INITIALLY DEFERRED;

CREATE TABLE employee_salary (
  employee_salary_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
  hourly_rate NUMERIC(10,2) NOT NULL CHECK (hourly_rate > 0),
  valid_from DATE NOT NULL,
  valid_to   DATE,
  CONSTRAINT ck_salary_validity CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE TABLE course (
  course_code TEXT PRIMARY KEY,
  course_name TEXT NOT NULL
);

CREATE TABLE course_layout_version (
  layout_version_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  course_code TEXT NOT NULL REFERENCES course(course_code),
  hp NUMERIC(4,1) NOT NULL CHECK (hp > 0),
  min_students INT NOT NULL CHECK (min_students >= 0),
  max_students INT NOT NULL CHECK (max_students > 0 AND max_students >= min_students),
  valid_from DATE NOT NULL,
  valid_to DATE,
  CONSTRAINT ck_layout_validity CHECK (valid_to IS NULL OR valid_to > valid_from)
);

CREATE TABLE course_instance (
  instance_id TEXT PRIMARY KEY,
  layout_version_id INT NOT NULL REFERENCES course_layout_version(layout_version_id),
  study_year INT NOT NULL CHECK (study_year >= 2000),
  study_period_id INT NOT NULL REFERENCES study_period(study_period_id),
  num_students INT NOT NULL CHECK (num_students >= 0)
);

CREATE TABLE planned_activity (
  course_instance_id TEXT NOT NULL REFERENCES course_instance(instance_id) ON DELETE CASCADE,
  activity_id INT NOT NULL REFERENCES teaching_activity(activity_id),
  planned_hours NUMERIC(10,2) NOT NULL CHECK (planned_hours >= 0),
  PRIMARY KEY (course_instance_id, activity_id)
);

CREATE TABLE allocation (
  allocation_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  employee_id INT NOT NULL REFERENCES employee(employee_id) ON DELETE CASCADE,
  course_instance_id TEXT NOT NULL REFERENCES course_instance(instance_id) ON DELETE CASCADE,
  activity_id INT NOT NULL REFERENCES teaching_activity(activity_id),
  allocated_hours NUMERIC(10,2) NOT NULL CHECK (allocated_hours >= 0),
  UNIQUE(employee_id, course_instance_id, activity_id)
);

-- Parameter tables (data-driven rules and coefficients)
CREATE TABLE allocation_rule (
  rule_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  max_instances_per_period INT NOT NULL CHECK (max_instances_per_period >= 0)
);

CREATE TABLE derived_activity_coeffs (
  activity_id INT PRIMARY KEY REFERENCES teaching_activity(activity_id),
  const NUMERIC(10,3) NOT NULL DEFAULT 0,
  hp_coeff NUMERIC(10,3) NOT NULL DEFAULT 0,
  students_coeff NUMERIC(10,3) NOT NULL DEFAULT 0
);


-- Ensure only NON-DERIVED activities appear in planned_activity
CREATE OR REPLACE FUNCTION check_planned_activity_non_derived()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $fn$
DECLARE is_der boolean;
BEGIN
  SELECT is_derived INTO is_der FROM teaching_activity WHERE activity_id = NEW.activity_id;
  IF is_der THEN
    RAISE EXCEPTION 'Cannot store planned hours for derived activity (activity_id=%).', NEW.activity_id;
  END IF;
  RETURN NEW;
END;
$fn$;

DROP TRIGGER IF EXISTS trg_planned_activity_not_derived ON planned_activity;
CREATE TRIGGER trg_planned_activity_not_derived
  BEFORE INSERT OR UPDATE OF activity_id ON planned_activity
  FOR EACH ROW
  EXECUTE FUNCTION check_planned_activity_non_derived();
