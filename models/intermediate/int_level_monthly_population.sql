/*
    INTERMEDIATE: population per level per month.

    Grain: one row per level per month.

    POINT-IN-TIME. A resident counts toward a level in a month only if their
    dwelling history says they actually lived there that month, and only if
    they were still alive and present.

    Previously this counted residents cumulatively against their CURRENT
    dwelling, which made every level's population monotonically flat. Fixed
    by range joining to int_resident_dwelling_history.
*/

with history as (

    select * from {{ ref('int_resident_dwelling_history') }}

),

dwellings as (

    select * from {{ ref('stg_census__dwellings') }}

),

zones as (

    select * from {{ ref('stg_seed__level_zones') }}

),

months as (

    select generate_series(
        '2022-01-01'::date,
        '2024-12-01'::date,
        '1 month'::interval
    )::date as month_start

),

-- the complete grid: every level in every month
level_months as (

    select
        months.month_start,
        zones.level_number,
        zones.zone_name,
        zones.supply_tier
    from months
    cross join zones

),

-- resolve each residency period to a level
residency_levels as (

    select
        history.resident_id,
        history.valid_from,
        history.valid_to,
        history.resident_status,
        dwellings.level_number,
        dwellings.dwelling_type
    from history
    inner join dwellings
        on history.dwelling_id = dwellings.dwelling_id

),

counted as (

    select
        level_months.month_start,
        level_months.level_number,
        level_months.zone_name,
        level_months.supply_tier,

        count(residency_levels.resident_id)                             as total_residents,

        count(residency_levels.resident_id) filter (
            where residency_levels.resident_status = 'active'
        )                                                                as active_residents,

        count(residency_levels.resident_id) filter (
            where residency_levels.dwelling_type = 'FAMILY'
        )                                                                as family_dwelling_residents

    from level_months
    left join residency_levels
        on  residency_levels.level_number = level_months.level_number
        -- residency started on or before the end of this month
        and residency_levels.valid_from < (level_months.month_start + interval '1 month')
        -- and had not ended before this month began
        -- (null valid_to = still living there)
        and (
                residency_levels.valid_to is null
             or residency_levels.valid_to >= level_months.month_start
            )

    group by 1, 2, 3, 4

)

select * from counted