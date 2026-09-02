/*
    MART: level dimension.
    Grain: one row per level. Current state plus lifetime aggregates.
*/

with zones as (

    select * from {{ ref('stg_seed__level_zones') }}

),

dwellings as (

    select
        level_number,
        count(*)                as dwelling_count,
        sum(capacity)           as total_capacity
    from {{ ref('stg_census__dwellings') }}
    group by 1

),

equipment as (

    select
        level_number,
        count(*)                                        as equipment_count,
        count(*) filter (where criticality = 'CRITICAL') as critical_equipment_count
    from {{ ref('stg_mech__equipment') }}
    group by 1

),

occupancy as (

    select distinct on (level_number)
        level_number,
        active_residents            as current_active_residents,
        occupancy_trend             as current_trend
    from {{ ref('fct_level_monthly_occupancy') }}
    order by level_number, month_start desc

),

final as (

    select
        zones.level_number,
        zones.zone_name,
        zones.supply_tier,
        zones.has_lift_access,

        coalesce(dwellings.dwelling_count, 0)               as dwelling_count,
        coalesce(dwellings.total_capacity, 0)               as total_capacity,
        coalesce(equipment.equipment_count, 0)              as equipment_count,
        coalesce(equipment.critical_equipment_count, 0)     as critical_equipment_count,

        coalesce(occupancy.current_active_residents, 0)     as current_active_residents,
        occupancy.current_trend,

        round(
            occupancy.current_active_residents::numeric / nullif(dwellings.total_capacity, 0),
            3
        )                                                    as capacity_utilisation

    from zones
    left join dwellings  on zones.level_number = dwellings.level_number
    left join equipment  on zones.level_number = equipment.level_number
    left join occupancy  on zones.level_number = occupancy.level_number

)

select * from final