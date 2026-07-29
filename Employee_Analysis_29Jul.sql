-- Employee SQL Analysis Project
-- Dataset: MySQL Employees Sample Database
-- Author: Khin Myat Thu
-- Description: SQL queries answering business questions about employees, departments, salaries, titles, and managers.


USE employees;

SELECT * FROM titles;

# 1. Find the current department of each employee (where to_date = '9999-01-01')
SELECT 
    e.emp_no,
    e.first_name,
    e.last_name,
    d.dept_no,
    d.dept_name,
    de.to_date
FROM employees e
JOIN dept_emp de
    ON e.emp_no = de.emp_no
JOIN departments d
    ON de.dept_no = d.dept_no
WHERE de.to_date = '9999-01-01'
ORDER BY e.emp_no;

# 2. Top 5 Highest-Paid Employees by Department and Gender (with Average Comparison)

WITH current_employee_salary AS (
    SELECT 
        e.emp_no,
        e.first_name,
        e.last_name,
        e.gender,
        d.dept_name,
        s.salary
    FROM employees e
    JOIN dept_emp de
        ON e.emp_no = de.emp_no
    JOIN departments d
        ON de.dept_no = d.dept_no
    JOIN salaries s
        ON e.emp_no = s.emp_no
    WHERE de.to_date = '9999-01-01'
      AND s.to_date = '9999-01-01'
),

salary_analysis AS (
    SELECT
        emp_no,
        first_name,
        last_name,
        gender,
        dept_name,
        salary,
        AVG(salary) OVER (
            PARTITION BY dept_name, gender
        ) AS avg_salary_by_dept_gender,
        ROW_NUMBER() OVER (
            PARTITION BY dept_name, gender
            ORDER BY salary DESC
        ) AS salary_rank
    FROM current_employee_salary
)

SELECT
    dept_name,
    gender,
    salary_rank,
    emp_no,
    first_name,
    last_name,
    salary,
    ROUND(avg_salary_by_dept_gender, 2) AS avg_salary_by_dept_gender,
    ROUND(salary - avg_salary_by_dept_gender, 2) AS salary_difference
FROM salary_analysis
WHERE salary_rank <= 5
ORDER BY dept_name, gender, salary_rank;

# 3. Find departments with average salary above 70,000
SELECT
	d.dept_no,
    d.dept_name,
    ROUND(AVG(s.salary), 2) AS average_salary
FROM departments d
JOIN dept_emp de
	ON d.dept_no = de.dept_no
JOIN salaries s
	ON de.emp_no = s.emp_no
WHERE de.to_date = '9999-01-01'
	AND s.to_date = '9999-01-01'
GROUP BY 
	d.dept_no, 
    d.dept_name
HAVING AVG(s.salary) > 70000
ORDER BY average_salary DESC;

# 4. Find the most common job title for each department.

WITH title_counts AS (
    SELECT
        d.dept_no,
        d.dept_name,
        t.title,
        COUNT(*) AS title_count
    FROM departments d
    JOIN dept_emp de
        ON d.dept_no = de.dept_no
    JOIN titles t
        ON de.emp_no = t.emp_no
    WHERE de.to_date = '9999-01-01'
      AND t.to_date = '9999-01-01'
    GROUP BY
        d.dept_no,
        d.dept_name,
        t.title
),

ranked_titles AS (
    SELECT
        dept_no,
        dept_name,
        title,
        title_count,
        RANK() OVER (
            PARTITION BY dept_no
            ORDER BY title_count DESC
        ) AS title_rank
    FROM title_counts
)

SELECT
    dept_no,
    dept_name,
    title AS most_common_job_title,
    title_count
FROM ranked_titles
WHERE title_rank = 1
ORDER BY dept_no;

# 5. Find employees who have changed departments more than 1 time.

SELECT
    e.emp_no,
    e.first_name,
    e.last_name,
    COUNT(DISTINCT de.dept_no) AS number_of_departments,
    GROUP_CONCAT(DISTINCT d.dept_name ORDER BY d.dept_name SEPARATOR ', ') AS departments_worked
FROM employees e
JOIN dept_emp de
    ON e.emp_no = de.emp_no
JOIN departments d
    ON de.dept_no = d.dept_no
GROUP BY
    e.emp_no,
    e.first_name,
    e.last_name
HAVING COUNT(DISTINCT de.dept_no) > 1
ORDER BY number_of_departments DESC, e.emp_no;

# 6. Calculate salary growth percentage for each employee.

WITH salary_ranked AS (
    SELECT
        emp_no,
        salary,
        from_date,
        to_date,

        ROW_NUMBER() OVER (
            PARTITION BY emp_no
            ORDER BY from_date ASC
        ) AS first_salary_rank,

        ROW_NUMBER() OVER (
            PARTITION BY emp_no
            ORDER BY from_date DESC
        ) AS latest_salary_rank
    FROM salaries
),

first_salary AS (
    SELECT
        emp_no,
        salary AS first_salary
    FROM salary_ranked
    WHERE first_salary_rank = 1
),

latest_salary AS (
    SELECT
        emp_no,
        salary AS latest_salary
    FROM salary_ranked
    WHERE latest_salary_rank = 1
)

SELECT
    e.emp_no,
    e.first_name,
    e.last_name,
    fs.first_salary,
    ls.latest_salary,
    ROUND(
        ((ls.latest_salary - fs.first_salary) / fs.first_salary) * 100,
        2
    ) AS salary_growth_percentage
FROM employees e
JOIN first_salary fs
    ON e.emp_no = fs.emp_no
JOIN latest_salary ls
    ON e.emp_no = ls.emp_no
ORDER BY salary_growth_percentage DESC;

-- salary growth after each salary change

WITH salary_changes AS (
    SELECT
        emp_no,
        salary,
        from_date,
        to_date,

        LAG(salary) OVER (
            PARTITION BY emp_no
            ORDER BY from_date
        ) AS previous_salary
    FROM salaries
)

SELECT
    e.emp_no,
    e.first_name,
    e.last_name,
    sc.from_date,
    sc.to_date,
    sc.previous_salary,
    sc.salary AS current_salary,
    ROUND(
        ((sc.salary - sc.previous_salary) / sc.previous_salary) * 100,
        2
    ) AS salary_growth_percentage
FROM employees e
JOIN salary_changes sc
    ON e.emp_no = sc.emp_no
WHERE sc.previous_salary IS NOT NULL
ORDER BY e.emp_no, sc.from_date;

# 7. Find departments with the most gender diversity (the count of male and female employees per department)

WITH gender_counts AS (
    SELECT
        d.dept_no,
        d.dept_name,

        SUM(CASE 
                WHEN e.gender = 'M' THEN 1 
                ELSE 0 
            END) AS male_count,

        SUM(CASE 
                WHEN e.gender = 'F' THEN 1 
                ELSE 0 
            END) AS female_count,

        COUNT(*) AS total_employees
    FROM departments d
    JOIN dept_emp de
        ON d.dept_no = de.dept_no
    JOIN employees e
        ON de.emp_no = e.emp_no
    WHERE de.to_date = '9999-01-01'
    GROUP BY
        d.dept_no,
        d.dept_name
)

SELECT
    dept_no,
    dept_name,
    male_count,
    female_count,
    total_employees,

    ABS(male_count - female_count) AS gender_count_difference,

    ROUND(female_count / total_employees * 100, 2) AS female_percentage,
    ROUND(male_count / total_employees * 100, 2) AS male_percentage

FROM gender_counts
ORDER BY gender_count_difference ASC;

# 8. Find each department manager’s average managed salary.

SELECT
    dm.emp_no AS manager_emp_no,
    m.first_name AS manager_first_name,
    m.last_name AS manager_last_name,
    d.dept_no,
    d.dept_name,
    ROUND(AVG(s.salary), 2) AS average_managed_salary,
    COUNT(DISTINCT de.emp_no) AS number_of_employees_managed
FROM dept_manager dm
JOIN employees m
    ON dm.emp_no = m.emp_no
JOIN departments d
    ON dm.dept_no = d.dept_no
JOIN dept_emp de
    ON dm.dept_no = de.dept_no
JOIN salaries s
    ON de.emp_no = s.emp_no
WHERE dm.to_date = '9999-01-01'
  AND de.to_date = '9999-01-01'
  AND s.to_date = '9999-01-01'
GROUP BY
    dm.emp_no,
    m.first_name,
    m.last_name,
    d.dept_no,
    d.dept_name
ORDER BY average_managed_salary DESC;

# 9. Create a view of current employees with salary information, then create a stored procedure to generate department-level summaries.

-- Create a view of current employees with salary information
CREATE OR REPLACE VIEW current_employee_salary_view AS
SELECT
    e.emp_no,
    e.first_name,
    e.last_name,
    e.gender,
    e.hire_date,
    d.dept_no,
    d.dept_name,
    s.salary
FROM employees e
JOIN dept_emp de
    ON e.emp_no = de.emp_no
JOIN departments d
    ON de.dept_no = d.dept_no
JOIN salaries s
    ON e.emp_no = s.emp_no
WHERE de.to_date = '9999-01-01'
  AND s.to_date = '9999-01-01';

-- Check the view
SELECT *
FROM current_employee_salary_view
LIMIT 10;

-- Drop the procedure first if it already exists
DROP PROCEDURE IF EXISTS department_level_salary_summary;

-- Create a stored procedure to generate department-level summaries
DELIMITER //

CREATE PROCEDURE department_level_salary_summary(IN p_dept_no CHAR(4))
BEGIN
    SELECT
        dept_no,
        dept_name,
        COUNT(emp_no) AS total_employees,
        ROUND(AVG(salary), 2) AS average_salary,
        MIN(salary) AS minimum_salary,
        MAX(salary) AS maximum_salary,
        SUM(CASE WHEN gender = 'M' THEN 1 ELSE 0 END) AS male_count,
        SUM(CASE WHEN gender = 'F' THEN 1 ELSE 0 END) AS female_count
    FROM current_employee_salary_view
    WHERE p_dept_no IS NULL
       OR dept_no = p_dept_no
    GROUP BY
        dept_no,
        dept_name
    ORDER BY
        dept_no;
END //

DELIMITER ;

-- Check the stored procedure: summary for one department
CALL department_level_salary_summary('d005');

-- Check the stored procedure: summary for all departments
CALL department_level_salary_summary(NULL);


#--------- END of Project---------#
