/*
    MART: level occupancy by month.

    Grain: one row per level per month.

    Answers Supply's question: which levels are gaining and losing population.
    Month-over-month movement is calculated here, once, so every consumer
    gets the same number.

    All rows retained. Flags, not filters - a level with zero residents is
    information, and filtering it out would destroy the denominator for any
    occupancy rate.
*/

with population as (

    select * from {{ ref('int_level_monthly_population') }}

),

with_movement as (

    select
        *,

        lag(active_residents) over (
            partition by level_number
            order by month_start
        ) as previous_active_residents,

        active_residents - lag(active_residents) over (
            partition by level_number
            order by month_start
        ) as resident_change

    from population

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['level_number', 'month_start']) }} as level_month_id,

        month_start,
        level_number,
        zone_name,
        supply_tier,

        total_residents,
        active_residents,
        family_dwelling_residents,
        previous_active_residents,
        resident_change,

        case
            when previous_active_residents is null then 'baseline'
            when resident_change > 0               then 'growing'
            when resident_change < 0               then 'shrinking'
            else 'stable'
        end as occupancy_trend,

        (active_residents = 0)   as is_empty_level,
        (resident_change < -2)   as is_significant_decline

    from with_movement

)

select * from final