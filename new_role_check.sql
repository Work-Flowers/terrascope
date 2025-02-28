WITH roles AS(
	SELECT 
		e.department,
		e.title,
		MIN(TO_DATE(e.start_date, 'DD/MM/YYYY')) AS role_created_date
	FROM hibob.employee AS e
	WHERE 
		e.lifecycle_status = 'Employed'
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