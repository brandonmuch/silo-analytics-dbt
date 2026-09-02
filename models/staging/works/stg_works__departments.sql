/*
    STAGING: works_db.departments
    Reference list. One row per department, with authorised establishment.
*/

with source as (

    select * from {{ source('works_db', 'departments') }}

),

renamed as (

    select
        cast(department_code as varchar)            as department_code,
        nullif(trim(department_name), '')           as department_name,
        cast(home_level as integer)                 as home_level,
        cast(establishment_headcount as integer)    as establishment_headcount

    from source

)

select * from renamed