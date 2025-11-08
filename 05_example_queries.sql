
-- 05_example_queries.sql
-- Ready-to-run verification & reporting queries

-- 1) Required hours per instance (planned + derived Admin/Exam from coefficients)
SELECT * FROM v_instance_required_hours ORDER BY instance_id, activity_name;

-- 2) Required hours with preparation multipliers (factors)
SELECT * FROM v_instance_required_hours_with_prep ORDER BY instance_id, activity_name;

-- 3) Teacher load per period (business rule is 4 by default)
SELECT * FROM v_teacher_load_per_period ORDER BY study_year, study_period_code, teacher_name;

-- 4) Allocation costs using salary at start of the period
SELECT * FROM v_allocation_costs ORDER BY course_instance_id, teacher_name, activity_name;

-- 5) Admin/Exam numbers for the two sample instances (for quick checking)
-- IV1351 / 200 students: Admin=83, Exam=177 (per formulas)
SELECT instance_id, activity_name, planned_hours
FROM v_instance_required_hours
WHERE instance_id='2025-50273' AND activity_name IN ('Administration','Examination')
ORDER BY activity_name;

-- IX1500 / 150 students: Admin=73, Exam=141
SELECT instance_id, activity_name, planned_hours
FROM v_instance_required_hours
WHERE instance_id='2025-50413' AND activity_name IN ('Administration','Examination')
ORDER BY activity_name;
