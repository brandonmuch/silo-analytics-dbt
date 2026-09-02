/*
    STAGING: works_db.job_assignments

    One row per job assignment. Source problems handled:
      1. ended_at is an EMPTY STRING for current assignments, not null.
         Left as-is it breaks every downstream range join, silently.
      2. status arrives in mixed casing.
      3. ~2% of department_codes do not exist in works_db.departments.
         Left intact here - caught by a test on the intermediate layer.
*/

with source as (

    select * from {{ source('works_db', 'job_assignments') }}

),

renamed as (

    select
        -- ids
        cast(assignment_id as varchar)              as assignment_id,
        cast(resident_id as varchar)                as resident_id,
        nullif(trim(upper(department_code)), '')    as department_code,

        -- attributes
        nullif(trim(role_title), '')                as role_title,
        nullif(trim(upper(shift_code)), '')         as shift_code,

        -- timestamps
        cast(started_at as timestamp)               as started_at,

        -- THE FIX: empty string becomes a real null before casting
        cast(nullif(trim(ended_at), '') as timestamp) as ended_at,

        cast(updated_at as timestamp)               as updated_at,

        -- normalise casing
        lower(trim(status))                          as assignment_status,

        -- explicit flag beats relying on a null check downstream
        (nullif(trim(ended_at), '') is null)        as is_current

    from source

)

select * from renamed