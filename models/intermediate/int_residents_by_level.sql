/*
    INTERMEDIATE: residents joined to their level and zone.

    Grain: one row per resident.

    All three joins are many-to-one (resident -> dwelling -> level -> zone),
    so the row count must stay equal to the resident count. Verified by a
    unique test on resident_id.

    left join throughout: a resident whose dwelling is missing, or a level
    absent from the Supply seed, should surface as a null we can test for -
    not silently vanish.
*/

with residents as (

    select * from {{ ref('stg_census__residents') }}

),

dwellings as (

    select * from {{ ref('stg_census__dwellings') }}

),

zones as (

    select * from {{ ref('stg_seed__level_zones') }}

),

joined as (

    select
        residents.resident_id,
        residents.full_name,
        residents.resident_status,
        residents.birth_date,
        residents.registered_at,

        dwellings.dwelling_id,
        dwellings.level_number,
        dwellings.dwelling_type,

        zones.zone_name,
        zones.supply_tier,
        zones.has_lift_access

    from residents
    left join dwellings
        on residents.dwelling_id = dwellings.dwelling_id
    left join zones
        on dwellings.level_number = zones.level_number

)

select * from joined