/*
    STAGING: mech_db.generator_readings

    158k hourly telemetry rows. Source problems:
      1. 200 exact duplicate rows from double-syncs
      2. null output_kw (dropped sensor readings)
      3. negative output_kw (impossible - sensor fault)

    Bad readings are NULLED, not deleted. The hour still happened; we just
    don't know what it produced. Deleting the row would make an outage
    indistinguishable from a sensor fault.
*/

with source as (

    select * from {{ source('mech_db', 'generator_readings') }}

),

deduplicated as (

    select
        *,
        row_number() over (
            partition by reading_id
            order by _synced_at desc
        ) as _row_num
    from source

),

renamed as (

    select
        -- ids
        cast(reading_id as varchar)                     as reading_id,
        nullif(trim(upper(generator_id)), '')           as generator_id,

        -- timestamps
        cast(read_at as timestamp)                      as read_at,
        cast(_synced_at as timestamp)                   as synced_at,

        -- measures: empty string -> null, then reject impossible values
        case
            when cast(nullif(trim(output_kw), '') as numeric(12,2)) < 0 then null
            else cast(nullif(trim(output_kw), '') as numeric(12,2))
        end                                              as output_kw,

        cast(temperature_c as numeric(8,2))             as temperature_c,
        cast(vibration_mm_s as numeric(8,3))            as vibration_mm_s,

        -- flags
        coalesce(is_manual_entry, false)                as is_manual_entry,
        (cast(nullif(trim(output_kw), '') as numeric(12,2)) < 0) as is_faulty_reading,

        -- how late did this row arrive? matters for the incremental model later
        cast(_synced_at as timestamp) - cast(read_at as timestamp) as sync_lag

    from deduplicated
    where _row_num = 1

)

select * from renamed