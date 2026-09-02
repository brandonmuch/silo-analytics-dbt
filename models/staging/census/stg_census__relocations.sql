/*
    STAGING: census_db.relocations
    One row per approved relocation. Source problem: reason contains
    empty strings mixed with real values.
*/

with source as (

    select * from {{ source('census_db', 'relocations') }}

),

renamed as (

    select
        -- ids
        cast(relocation_id as varchar)          as relocation_id,
        cast(resident_id as varchar)            as resident_id,
        cast(from_dwelling_id as varchar)       as from_dwelling_id,
        cast(to_dwelling_id as varchar)         as to_dwelling_id,

        -- timestamps
        cast(relocated_at as timestamp)         as relocated_at,

        -- empty strings become an explicit category, not null
        coalesce({{ clean_string('reason', 'upper') }}, 'UNSPECIFIED') as relocation_reason

    from source

)

select * from renamed