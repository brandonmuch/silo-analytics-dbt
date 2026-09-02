/*
    STAGING: census_db.dwellings
    One row per dwelling unit. Clean source - nothing planted here.
*/

with source as (

    select * from {{ source('census_db', 'dwellings') }}

),

renamed as (

    select
        -- ids
        cast(dwelling_id as varchar)      as dwelling_id,

        -- attributes
        cast(level_number as integer)     as level_number,
        cast(unit_number as integer)      as unit_number,
        nullif(trim(upper(dwelling_type)), '') as dwelling_type,
        cast(capacity as integer)         as capacity

    from source

)

select * from renamed