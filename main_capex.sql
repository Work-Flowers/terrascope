WITH active_projects AS (
	SELECT DISTINCT
		p.id AS project_id,
		p.name AS project_name,
		p.state AS project_status,
		p.started_at,
		p.target_date,
		p.completed_at,
		DATE_TRUNC('month', i.completed_at)::DATE AS issue_completion_date,
		ip.initiative_name
	FROM linear.project AS p
	INNER JOIN google_sheets.initiatives_to_projects AS ip
		ON p.id = ip.project_id
		AND ip.initiative_id = '063b054f-7b7d-49b0-9f93-96701ee6ee9d' -- ID for 2025 Features Roadmap
	INNER JOIN linear.issue AS i
		ON p.id = i.project_id
		AND i._fivetran_deleted IS FALSE
	INNER JOIN linear.workflow_state AS ws	
		ON i.state_id = ws.id
		AND ws.name = 'Done'
		AND ws._fivetran_deleted IS FALSE
 	WHERE p._fivetran_deleted IS FALSE
),

employee_history AS (
	SELECT
		employee_id,
		status,
		effective_date AS from_date,
		COALESCE(LEAD(effective_date, 1) OVER(PARTITION BY employee_id ORDER BY effective_date), '9999-01-01') AS to_date
	FROM hibob.employee_life_cycle_history
)
-- first part of the query that identifies only shared resource members -- 

SELECT DISTINCT 
-- member's details -- 
	'shared_resource' AS section,
	e.id,
	e.full_name,
	e.email,
	e.department,
	et.team_name AS team,
	e.title,
	cm.development_share, 
	cm.shared_resource,
	INITCAP(hist.status) AS status,
	hist.from_date,
	
	-- project details -- 
	active_projects.project_id,
	active_projects.project_name,
	INITCAP(active_projects.project_status) AS project_status,
	DATE_TRUNC('month', active_projects.started_at)::DATE AS project_start_date,
	active_projects.target_date::DATE AS project_target_date,
	active_projects.completed_at::DATE AS project_completed_date,
	active_projects.issue_completion_date AS issue_completed_at,
	active_projects.initiative_name

FROM google_sheets.capex_mapping AS cm
INNER JOIN hibob.employee AS e
	ON TRIM(LOWER(cm.role)) = TRIM(LOWER(e.title))
	AND cm.department = e.department
INNER JOIN hibob.vw_employee_team AS et
	ON e.id = et.employee_id
	
CROSS JOIN active_projects  
INNER JOIN employee_history AS hist
	ON e.id = hist.employee_id
	AND hist.status = 'employed'
	AND active_projects.issue_completion_date BETWEEN hist.from_date AND hist.to_date
WHERE
	1 = 1
	AND cm.shared_resource IS TRUE	

UNION


SELECT DISTINCT 
	'actual_project_members' AS section,
	-- member's details -- 
	e.id,
	e.full_name,
	e.email,
	e.department,
	et.team_name AS team,
	e.title,
	map.development_share,
	map.shared_resource,
	INITCAP(hist.status) AS status,
	hist.from_date,
	
	-- project details -- 
	p.id AS project_id,
	p.name AS project_name,
	INITCAP(p.state) AS project_status,
	DATE_TRUNC('month', p.started_at)::DATE AS project_start_date,
	p.target_date::DATE AS project_target_date,
	p.completed_at::DATE AS project_completed_date,
	active_projects.issue_completion_date AS issue_completed_at,
	active_projects.initiative_name
FROM google_sheets.capex_mapping AS map
INNER JOIN hibob.employee AS e
	-- TRIM and LOWER for trailing white space/improper capitalisation, and JOIN on department since some job titles may exist in multiple departments 
	ON TRIM(LOWER(map.role)) = TRIM(LOWER(e.title))
	AND map.department = e.department
    INNER JOIN hibob.vw_employee_team AS et
        ON e.id = et.employee_id
INNER JOIN linear.users AS u
	ON LOWER(e.email) = LOWER(u.email)
LEFT JOIN linear.project_member AS mem
	ON u.id = mem.member_id
	AND mem._fivetran_deleted IS FALSE
LEFT JOIN linear.project AS p
	ON mem.project_id = p.id
	AND p._fivetran_deleted IS FALSE

-- INNER JOIN to include only truly active projects, with storypoints completed within the month --
INNER JOIN active_projects
	ON mem.project_id = active_projects.project_id
INNER JOIN employee_history AS hist
	ON e.id = hist.employee_id
	AND hist.status = 'employed'
	AND active_projects.issue_completion_date BETWEEN hist.from_date AND hist.to_date

-- only capitalisable resources from within CapEx Roles Mapping (filters out non capitalisable roles in case they are somehow within the sheet) --
-- also filters only active employees or terminated/garden leave employees who contributed during the reporting month -- 
WHERE 
	1 = 1
	AND map.development_share > 0