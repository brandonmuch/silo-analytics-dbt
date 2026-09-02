/*
    STAGING: seed level_zones
    Hand-maintained by Supply. Maps each of the 144 levels to a zone
    and supply tier. Staged like any other source so it follows the
    same naming and testing conventions.
*/

with source as (

    select * from {{ ref('level_zones') }}

),

renamed as (

    select
        cast(level_number as integer)           as level_number,
        nullif(trim(zone_name), '')             as zone_name,
        cast(supply_tier as integer)            as supply_tier,
        coalesce(has_lift_access, false)        as has_lift_access

    from source

)

select * from renamed