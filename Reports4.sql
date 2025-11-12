-- 05b_reports_versioned.sql
SET search_path = dsp, public;

-- Show that P1 vs P2 for IV1351 use different HP due to versioning
SELECT instance_id, course_code, layout_version_no, study_period, study_year, hp
FROM v_course_instance_header
WHERE course_code='IV1351'
ORDER BY study_year, study_period;

-- Effective hours by activity per instance
SELECT * FROM v_activity_hours ORDER BY course_instance_id, activity_name;

-- Total hours per instance
SELECT * FROM v_course_instance_total_hours ORDER BY instance_id;

-- Allocation cost (uses salary versions)
SELECT * FROM v_allocation_cost ORDER BY course_instance_id, allocation_id;

-- Instance total cost
SELECT * FROM v_course_instance_cost ORDER BY instance_id;

-- Department cost by period
SELECT * FROM v_department_cost_by_period ORDER BY department_name, study_year, study_period;

-- Limit check (should be empty)
WITH counts AS (
  SELECT a.employee_id, ci.study_year, ci.study_period, COUNT(DISTINCT a.course_instance_id) AS n
  FROM allocation a
  JOIN course_instance ci ON ci.instance_id = a.course_instance_id
  GROUP BY a.employee_id, ci.study_year, ci.study_period
)
SELECT * FROM counts WHERE n > (SELECT max_instances_per_period FROM allocation_rule LIMIT 1);
