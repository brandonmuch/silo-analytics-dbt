/*
    STAGING: mech_db.maintenance_orders

    Source problems:
      1. closed_at and labour_hours are empty strings for open orders
      2. ~1% of orders close BEFORE they open (data entry / clock error).
         Not corrected here - flagged, and caught by a singular test later.
*/

with source as (

    select * from {{ source('mech_db', 'maintenance_orders') }}

),

renamed as (

    select
        -- ids
        cast(order_id as varchar)                       as order_id,
        cast(equipment_id as varchar)                   as equipment_id,
        nullif(trim(upper(department_code)), '')        as department_code,

        -- timestamps: empty string -> null BEFORE casting
        cast(opened_at as timestamp)                    as opened_at,
        cast(nullif(trim(closed_at), '') as timestamp)  as closed_at,

        -- numerics: same pattern
        cast(nullif(trim(labour_hours), '') as numeric(8,1)) as labour_hours,

        -- attributes
        nullif(trim(upper(priority)), '')               as priority,
        nullif(trim(upper(status)), '')                 as order_status,

        -- flags
        (nullif(trim(closed_at), '') is null)           as is_open

    from source

)

select * from renamed