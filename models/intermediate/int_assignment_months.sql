/*
    INTERMEDIATE: one row per assignment per month it was active.

    Grain: assignment_id + month_start.

    Expands each assignment's date range into monthly rows via a range join
    to a generated spine. Around 2% of assignments carry department codes
    absent from works_db.departments - kept via left join and surfaced as
    'UNMAPPED' so they can be counted rather than silently dropped.
*/

with assignments as (

    select * from {{ ref('stg_works__assignments') }}

),

departments as (

    select * from {{ ref('stg_works__departments') }}

),

months as (

    select generate_series(
        '2022-01-01'::date,
        '2024-12-01'::date,
        '1 month'::interval
    )::date as month_start

),

-- expand each assignment across every month it covered
assignment_months as (

    select
        months.month_start,
        assignments.assignment_id,
        assignments.resident_id,
        assignments.department_code,
        assignments.role_title,
        assignments.shift_code,
        assignments.started_at,
        assignments.ended_at,
        assignments.is_current

    from months
    inner join assignments
        on  months.month_start >= date_trunc('month', assignments.started_at)
        and (
                assignments.ended_at is null
             or months.month_start <= date_trunc('month', assignments.ended_at)
            )

),

-- attach department detail; unmapped codes survive as 'UNMAPPED'
enriched as (

    select
        assignment_months.month_start,
        assignment_months.assignment_id,
        assignment_months.resident_id,
        assignment_months.department_code,
        assignment_months.role_title,
        assignment_months.shift_code,
        assignment_months.is_current,

        coalesce(departments.department_name, 'UNMAPPED')  as department_name,
        departments.home_level,
        departments.establishment_headcount,

        (departments.department_code is null)              as is_unmapped_department

    from assignment_months
    left join departments
        on assignment_months.department_code = departments.department_code

)

select * from enriched