-- Seeds the versioned model and demonstrates course HP changes and salary changes.
SET search_path = dsp, public;

-- Study periods
INSERT INTO study_period(code, quarter_num) VALUES
 ('P1',1),('P2',2),('P3',3),('P4',4)
ON CONFLICT (code) DO NOTHING;

-- Job titles
INSERT INTO job_title(job_title) VALUES
 ('Lecturer'), ('Senior Lecturer'), ('Professor'), ('Teaching Assistant')
ON CONFLICT (job_title) DO NOTHING;

-- People
INSERT INTO person(personal_number, first_name, last_name, email, phone_number, address) VALUES
 ('PN1001','Anna','Lind','anna.lind@example.edu','+46-70-1111111','Valhallavägen 1, 114 28 Stockholm'),
 ('PN1002','Björn','Sund','bjorn.sund@example.edu','+46-70-2222222','Drottninggatan 2, 111 51 Stockholm'),
 ('PN1003','Clara','Nyström','clara.nystrom@example.edu','+46-70-3333333','Sveavägen 3, 111 57 Stockholm'),
 ('PN1004','David','Åberg','david.aberg@example.edu','+46-70-4444444','Birger Jarlsgatan 4, 114 34 Stockholm'),
 ('PN1005','Elin','Wik','elin.wik@example.edu','+46-70-5555555','KTH Campus, 114 28 Stockholm'),
 ('PN1006','Fredrik','Holm','fredrik.holm@example.edu','+46-70-6666666','SSE Sveavägen 65, 113 83 Stockholm')
ON CONFLICT (personal_number) DO NOTHING;

-- Departments
INSERT INTO department(department_name) VALUES
 ('Computer Science'),
 ('Mathematics')
ON CONFLICT (department_name) DO NOTHING;

-- Employees
INSERT INTO employee(personal_number, department_id, job_title, skill_set, supervisor_id) VALUES
 ('PN1001', (SELECT department_id FROM department WHERE department_name='Computer Science'), 'Professor', 'DB, Data Modeling, Lectures', NULL),
 ('PN1002', (SELECT department_id FROM department WHERE department_name='Computer Science'), 'Senior Lecturer', 'SQL, Labs, Tutorials', 1),
 ('PN1003', (SELECT department_id FROM department WHERE department_name='Computer Science'), 'Lecturer', 'Lectures, Admin, Exams', 2),
 ('PN1004', (SELECT department_id FROM department WHERE department_name='Mathematics'), 'Professor', 'Discrete Math, Lectures', NULL),
 ('PN1005', (SELECT department_id FROM department WHERE department_name='Mathematics'), 'Senior Lecturer', 'Seminars, Tutorials', 4),
 ('PN1006', (SELECT department_id FROM department WHERE department_name='Computer Science'), 'Teaching Assistant', 'Labs, Tutorials', 2)
ON CONFLICT DO NOTHING;

-- Department managers
UPDATE department SET manager_employee_id = 1 WHERE department_name='Computer Science';
UPDATE department SET manager_employee_id = 4 WHERE department_name='Mathematics';

-- Course layout identity
INSERT INTO course_layout(course_code, course_name) VALUES
 ('IV1351','Data Storage Paradigms'),
 ('IX1500','Discrete Mathematics')
ON CONFLICT (course_code) DO NOTHING;

-- Version 1 for both courses
INSERT INTO course_layout_version(course_code, version_no, hp, min_students, max_students) VALUES
 ('IV1351', 1, 7.5, 50, 250),
 ('IX1500', 1, 7.5, 50, 150)
ON CONFLICT DO NOTHING;

-- Version 2 for IV1351 where HP changes from 7.5 to 15.0 (used in P2)
INSERT INTO course_layout_version(course_code, version_no, hp, min_students, max_students) VALUES
 ('IV1351', 2, 15.0, 50, 250)
ON CONFLICT DO NOTHING;

-- Course instances
-- For IV1351 we have two instances in 2025: P1 uses version 1; P2 uses version 2
INSERT INTO course_instance(instance_id, course_code, layout_version_no, study_year, study_period, num_students) VALUES
 ('2025-50001','IV1351', 1, 2025, 'P1', 180),
 ('2025-50273','IV1351', 2, 2025, 'P2', 200),
 ('2025-50413','IX1500', 1, 2025, 'P1', 150)
ON CONFLICT DO NOTHING;

-- Teaching activities
INSERT INTO teaching_activity(activity_name, factor, is_derived) VALUES
 ('Lecture', 3.60, FALSE),
 ('Lab', 2.40, FALSE),
 ('Tutorial', 2.40, FALSE),
 ('Seminar', 1.80, FALSE),
 ('Other', 1.00, FALSE),
 ('Administration', 1.00, TRUE),
 ('Examination', 1.00, TRUE)
ON CONFLICT (activity_name) DO NOTHING;

-- Derived activity coefficients per assignment brief
INSERT INTO derived_activity_coeffs(activity_id, const, hp_coeff, students_coeff)
SELECT activity_id, 28.0000, 2.0000, 0.2000 FROM teaching_activity WHERE activity_name='Administration'
ON CONFLICT (activity_id) DO NOTHING;

INSERT INTO derived_activity_coeffs(activity_id, const, hp_coeff, students_coeff)
SELECT activity_id, 32.0000, 0.0000, 0.7250 FROM teaching_activity WHERE activity_name='Examination'
ON CONFLICT (activity_id) DO NOTHING;

-- Rule parameter
INSERT INTO allocation_rule(max_instances_per_period) VALUES (4);

-- Planned (non-derived) hours (same as the handout for the original two instances, plus one for IV1351 P1)
-- IV1351 P2 (instance 2025-50273), layout version 2
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 20 FROM teaching_activity WHERE activity_name='Lecture';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 80 FROM teaching_activity WHERE activity_name='Tutorial';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 40 FROM teaching_activity WHERE activity_name='Lab';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 80 FROM teaching_activity WHERE activity_name='Seminar';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50273', activity_id, 650 FROM teaching_activity WHERE activity_name='Other';

-- IX1500 P1 (instance 2025-50413) from handout
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 44 FROM teaching_activity WHERE activity_name='Lecture';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 0 FROM teaching_activity WHERE activity_name='Tutorial';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 0 FROM teaching_activity WHERE activity_name='Lab';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 64 FROM teaching_activity WHERE activity_name='Seminar';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50413', activity_id, 200 FROM teaching_activity WHERE activity_name='Other';

-- IV1351 P1 (instance 2025-50001) – simple small plan to show independence from P2
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50001', activity_id, 16 FROM teaching_activity WHERE activity_name='Lecture';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50001', activity_id, 40 FROM teaching_activity WHERE activity_name='Tutorial';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50001', activity_id, 24 FROM teaching_activity WHERE activity_name='Lab';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50001', activity_id, 40 FROM teaching_activity WHERE activity_name='Seminar';
INSERT INTO planned_activity(course_instance_id, activity_id, planned_hours)
SELECT '2025-50001', activity_id, 120 FROM teaching_activity WHERE activity_name='Other';

-- Salaries (versioned)

-- Version 1 salaries
INSERT INTO employee_salary_history(employee_id, version_no, salary_hour) VALUES
 (1, 1, 950.00),
 (2, 1, 650.00),
 (3, 1, 550.00),
 (4, 1, 900.00),
 (5, 1, 620.00),
 (6, 1, 350.00);

-- Version 2 salary change for employee 2 (e.g., promotion before P2)
INSERT INTO employee_salary_history(employee_id, version_no, salary_hour) VALUES
 (2, 2, 700.00);

-- ===== Allocations with explicit salary_version_id =====

-- Helper: pick salary_version_id by (employee_id, version_no)
-- IV1351 P2 (version_no=2), assume employee 2 is on salary version 2 in P2
INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 2, '2025-50273', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 2 AND version_no = 2),
       (20*3.6)*0.60 FROM teaching_activity ta WHERE ta.activity_name='Lecture';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 3, '2025-50273', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 3 AND version_no = 1),
       (20*3.6)*0.40 FROM teaching_activity ta WHERE ta.activity_name='Lecture';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 6, '2025-50273', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 6 AND version_no = 1),
       (40*2.4) FROM teaching_activity ta WHERE ta.activity_name='Lab';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 2, '2025-50273', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 2 AND version_no = 2),
       (80*2.4)*0.50 FROM teaching_activity ta WHERE ta.activity_name='Tutorial';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 6, '2025-50273', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 6 AND version_no = 1),
       (80*2.4)*0.50 FROM teaching_activity ta WHERE ta.activity_name='Tutorial';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 5, '2025-50273', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 5 AND version_no = 1),
       (80*1.8) FROM teaching_activity ta WHERE ta.activity_name='Seminar';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 3, '2025-50273', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 3 AND version_no = 1),
       (650*1.0) FROM teaching_activity ta WHERE ta.activity_name='Other';

-- Derived allocations (use versioned HP automatically via view)
INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 3, v.course_instance_id, v.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 3 AND version_no = 1),
       v.effective_hours
FROM v_activity_hours v
JOIN teaching_activity ta ON ta.activity_id = v.activity_id AND ta.activity_name='Administration'
WHERE v.course_instance_id = '2025-50273';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 2, v.course_instance_id, v.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 2 AND version_no = 2),
       v.effective_hours
FROM v_activity_hours v
JOIN teaching_activity ta ON ta.activity_id = v.activity_id AND ta.activity_name='Examination'
WHERE v.course_instance_id = '2025-50273';

-- IX1500 P1 (uses salary version 1 for everyone)
INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 4, '2025-50413', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 4 AND version_no = 1),
       (44*3.6) FROM teaching_activity ta WHERE ta.activity_name='Lecture';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 5, '2025-50413', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 5 AND version_no = 1),
       (64*1.8) FROM teaching_activity ta WHERE ta.activity_name='Seminar';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 3, '2025-50413', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 3 AND version_no = 1),
       (200*1.0) FROM teaching_activity ta WHERE ta.activity_name='Other';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 3, v.course_instance_id, v.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 3 AND version_no = 1),
       v.effective_hours
FROM v_activity_hours v
JOIN teaching_activity ta ON ta.activity_id = v.activity_id AND ta.activity_name='Administration'
WHERE v.course_instance_id = '2025-50413';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 4, v.course_instance_id, v.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 4 AND version_no = 1),
       v.effective_hours
FROM v_activity_hours v
JOIN teaching_activity ta ON ta.activity_id = v.activity_id AND ta.activity_name='Examination'
WHERE v.course_instance_id = '2025-50413';

-- IV1351 P1 (uses layout version 1 and earlier salaries)
INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 1, '2025-50001', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 1 AND version_no = 1),
       (16*3.6) FROM teaching_activity ta WHERE ta.activity_name='Lecture';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 6, '2025-50001', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 6 AND version_no = 1),
       (24*2.4) FROM teaching_activity ta WHERE ta.activity_name='Lab';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 2, '2025-50001', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 2 AND version_no = 1),
       (40*2.4) FROM teaching_activity ta WHERE ta.activity_name='Tutorial';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 5, '2025-50001', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 5 AND version_no = 1),
       (40*1.8) FROM teaching_activity ta WHERE ta.activity_name='Seminar';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 3, '2025-50001', ta.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 3 AND version_no = 1),
       (120*1.0) FROM teaching_activity ta WHERE ta.activity_name='Other';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 3, v.course_instance_id, v.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 3 AND version_no = 1),
       v.effective_hours
FROM v_activity_hours v
JOIN teaching_activity ta ON ta.activity_id = v.activity_id AND ta.activity_name='Administration'
WHERE v.course_instance_id = '2025-50001';

INSERT INTO allocation(employee_id, course_instance_id, activity_id, salary_version_id, allocated_hours)
SELECT 1, v.course_instance_id, v.activity_id,
       (SELECT salary_version_id FROM employee_salary_history WHERE employee_id = 1 AND version_no = 1),
       v.effective_hours
FROM v_activity_hours v
JOIN teaching_activity ta ON ta.activity_id = v.activity_id AND ta.activity_name='Examination'
WHERE v.course_instance_id = '2025-50001';

-- After setting managers, enforce NOT NULL per 'every department has a manager'
ALTER TABLE department ALTER COLUMN manager_employee_id SET NOT NULL;
