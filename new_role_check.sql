WITH roles AS(
	SELECT 
		cd.name AS department,
		ct.name AS title,
		MIN(e.effective_date) AS role_created_date
	FROM hibob.employee_work_history AS e
	INNER JOIN hibob.company AS ct
		ON e.title = ct.id
	INNER JOIN hibob.company AS cd
		ON e.department = cd.id
	GROUP BY 1,2
)

SELECT
	e.*
FROM roles AS e
LEFT JOIN google_sheets.capex_mapping AS cm
	ON e.title = cm.role
WHERE 
	cm.department IS NULL
	AND e.role_created_date >= CURRENT_DATE + INTERVAL '-1 month'