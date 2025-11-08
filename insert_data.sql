
-- 04_seed.sql
-- Seed data mirroring the project handout

-- Study periods
INSERT INTO study_period(code, quarter_num) VALUES
 ('P1',1),('P2',2),('P3',3),('P4',4);

-- Teaching activities (factors per handout)
INSERT INTO teaching_activity(name, factor, is_derived) VALUES
 ('Lecture', 3.60, FALSE),
 ('Lab', 2.40, FALSE),
 ('Tutorial', 2.40, FALSE),
 ('Seminar', 1.80, FALSE),
 ('Other', 1.00, FALSE),
 ('Administration', 1.00, TRUE),
 ('Examination', 1.00, TRUE);

-- Parameter: allocation rule (max instances per teacher per period)
INSERT INTO allocation_rule(max_instances_per_period) VALUES (4);

-- Derived activity coefficients (hours = const + hp_coeff*HP + students_coeff*Students)
-- Exam: 32 + 0.725 * Students
INSERT INTO derived_activity_coeffs(activity_id, const, hp_coeff, students_coeff)
SELECT activity_id, 32.000, 0.000, 0.725 FROM teaching_activity WHERE name='Examination';

-- Admin: 28 + 2*HP + 0.2 * Students
INSERT INTO derived_activity_coeffs(activity_id, const, hp_coeff, students_coeff)
SELECT activity_id, 28.000, 2.000, 0.200 FROM teaching_activity WHERE name='Administration';

-- Courses
INSERT INTO course(course_code, course_name) VALUES
 ('IV1351','Data Storage Paradigms'),
 ('IX1500','Discrete Mathematics');

-- Layout versions (HP/min/max) valid from 2025-01-01
INSERT INTO course_layout_version(course_code, hp, min_students, max_students, valid_from, valid_to) VALUES
 ('IV1351', 7.5, 50, 250, DATE '2025-01-01', NULL),
 ('IX1500', 7.5, 50, 150, DATE '2025-01-01', NULL);

-- Course instances (IDs taken from handout examples)
INSERT INTO course_instance(instance_id, layout_version_id, study_year, study_period_id, num_students) VALUES
 ('2025-50273', 1, 2025, (SELECT study_period_id FROM study_period WHERE code='P2'), 200),
 ('2025-50413', 2, 2025, (SELECT study_period_id FROM study_period WHERE code='P1'), 150);

-- Planned hours for NON-derived activities (from the handout table)
-- IV1351 (2025-50273): Lecture 20, Tutorial 80, Lab 40, Seminar 80, Other 650
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 20 FROM teaching_activity WHERE name='Lecture';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 80 FROM teaching_activity WHERE name='Tutorial';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 40 FROM teaching_activity WHERE name='Lab';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 80 FROM teaching_activity WHERE name='Seminar';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 650 FROM teaching_activity WHERE name='Other';

-- IX1500 (2025-50413): Lecture 44, Seminar 64, Other 200
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 44 FROM teaching_activity WHERE name='Lecture';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 64 FROM teaching_activity WHERE name='Seminar';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 200 FROM teaching_activity WHERE name='Other';

-- People, employees, departments, job titles
INSERT INTO person(personal_number, first_name, last_name, phone_number, address) VALUES
 ('19700101-1234','Alice','Andersson','070-111111','Sveavägen 1, Stockholm'),
 ('19750202-2222','Bjorn','Berg','070-222222','Drottninggatan 2, Stockholm'),
 ('19800303-3333','Carin','Carlsson','070-333333','Vasagatan 3, Stockholm');

INSERT INTO job_title(name) VALUES ('Senior Lecturer'), ('Lecturer');

INSERT INTO department(department_name) VALUES ('Computer Science'), ('Mathematics');

-- Employees (link persons to departments and titles)
INSERT INTO employee(person_id, department_id, job_title_id, skill_set, supervisor_employee_id) VALUES
 (1, 1, 1, 'Databases; ER Modeling', NULL),  -- employee_id = 1
 (2, 1, 2, 'Programming; Systems', 1),       -- employee_id = 2
 (3, 2, 2, 'Discrete Math', NULL);           -- employee_id = 3

-- Set managers (FK deferrable; set after employees exist)
UPDATE department SET manager_employee_id = 1 WHERE department_name='Computer Science';
UPDATE department SET manager_employee_id = 3 WHERE department_name='Mathematics';

-- Salary history
INSERT INTO employee_salary(employee_id, hourly_rate, valid_from, valid_to) VALUES
 (1, 500.00, DATE '2025-01-01', NULL),
 (2, 350.00, DATE '2025-01-01', NULL),
 (3, 400.00, DATE '2025-01-01', NULL);

-- Example allocations (each teacher gets some activities in each instance)
-- IV1351 (2025-50273)
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 1, '2025-50273', activity_id, 10 FROM teaching_activity WHERE name='Lecture';
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 2, '2025-50273', activity_id, 10 FROM teaching_activity WHERE name='Lecture';
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 1, '2025-50273', activity_id, 40 FROM teaching_activity WHERE name='Tutorial';
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 2, '2025-50273', activity_id, 40 FROM teaching_activity WHERE name='Tutorial';
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 1, '2025-50273', activity_id, 40 FROM teaching_activity WHERE name='Lab';
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 1, '2025-50273', activity_id, 80 FROM teaching_activity WHERE name='Seminar';

-- IX1500 (2025-50413)
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 3, '2025-50413', activity_id, 44 FROM teaching_activity WHERE name='Lecture';
INSERT INTO allocation(employee_id, course_instance_id, activity_id, allocated_hours)
SELECT 3, '2025-50413', activity_id, 64 FROM teaching_activity WHERE name='Seminar';
