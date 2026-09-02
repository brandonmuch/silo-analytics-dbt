/*
    MART: department staffing by month.

    Grain: one row per department per month.

    Answers Works' question: actual headcount versus authorised establishment.
    Unmapped department codes are retained as their own row rather than dropped,
    so the 2% of assignments with codes missing from the reference table stay
    visible and countable.
*/

with assignment_months as (

    select * from {{ ref('int_assignment_months') }}

),

aggregated as (

    select
        month_start,
        department_code,
        department_name,
        max(establishment_headcount)                        as establishment_headcount,
        bool_or(is_unmapped_department)                     as is_unmapped_department,

        count(distinct resident_id)                         as headcount,
        count(distinct assignment_id)                       as assignment_count,

        count(distinct resident_id) filter (where shift_code = 'DAY')   as day_shift_headcount,
        count(distinct resident_id) filter (where shift_code = 'SWING') as swing_shift_headcount,
        count(distinct resident_id) filter (where shift_code = 'NIGHT') as night_shift_headcount,

        count(distinct resident_id) filter (where role_title = 'Shadow') as shadow_count

    from assignment_months
    group by 1, 2, 3

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['department_code', 'month_start']) }} as department_month_id,

        month_start,
        department_code,
        department_name,
        establishment_headcount,

        headcount,
        assignment_count,
        day_shift_headcount,
        swing_shift_headcount,
        night_shift_headcount,
        shadow_count,

        headcount - establishment_headcount                             as headcount_variance,

        round(
            headcount::numeric / nullif(establishment_headcount, 0),
            3
        )                                                                as establishment_fill_rate,

        (headcount < establishment_headcount)                            as is_understaffed,
        is_unmapped_department

    from aggregated

)

select * from final