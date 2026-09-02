/*
    STAGING: mech_db.equipment
    One row per tracked asset, with a criticality rating.
*/

with source as (

    select * from {{ source('mech_db', 'equipment') }}

),

renamed as (

    select
        cast(equipment_id as varchar)               as equipment_id,
        nullif(trim(equipment_name), '')            as equipment_name,
        cast(level_number as integer)               as level_number,
        nullif(trim(upper(criticality)), '')        as criticality,
        cast(installed_on as date)                  as installed_on,

        -- rank for weighting the maintenance backlog later
        case upper(trim(criticality))
            when 'CRITICAL' then 1
            when 'HIGH'     then 2
            when 'MEDIUM'   then 3
            when 'LOW'      then 4
            else 9
        end                                          as criticality_rank

    from source

)

select * from renamed