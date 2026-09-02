/*
    STAGING: census_db.residents

    One row per resident. Handles four known source problems:
      1. status arrives in four casings, plus empty strings
      2. an undocumented 'unregistered' status value
      3. soft-deleted rows flagged with _deleted
      4. 45 duplicate rows from a botched replication batch
*/

with source as (

    select * from {{ source('census_db', 'residents') }}

),

deduplicated as (

    -- The replication job produces exact duplicates. Keep one row per
    -- resident, preferring the most recently synced version.
    -- Postgres has no QUALIFY, so the ranking needs its own CTE.
    select
        *,
        row_number() over (
            partition by resident_id
            order by _synced_at desc, updated_at desc
        ) as _row_num
    from source

),

renamed as (

    select
        -- ids
        cast(resident_id as varchar)              as resident_id,
        cast(dwelling_id as varchar)              as dwelling_id,

        -- names
        nullif(trim(given_name), '')              as given_name,
        nullif(trim(family_name), '')             as family_name,
        nullif(trim(given_name), '') || ' ' || nullif(trim(family_name), '') as full_name,

        -- normalise the status mess into a controlled vocabulary
        case
            when nullif(trim(lower(status)), '') = 'active'       then 'active'
            when nullif(trim(lower(status)), '') = 'deceased'     then 'deceased'
            when nullif(trim(lower(status)), '') = 'relocated'    then 'relocated'
            when nullif(trim(lower(status)), '') is null          then 'unknown'
            else 'unknown'
        end                                        as resident_status,

        -- dates
        cast(birth_date as date)                   as birth_date,
        cast(registered_at as timestamp)           as registered_at,
        cast(updated_at as timestamp)              as updated_at,
        cast(_synced_at as timestamp)              as synced_at,

        -- flags
        coalesce(_deleted, false)                  as is_deleted

    from deduplicated
    where _row_num = 1

)

select * from renamed
where not is_deleted