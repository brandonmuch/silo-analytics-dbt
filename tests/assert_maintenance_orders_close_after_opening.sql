{{ config(severity='warn') }}
/*
    A maintenance order cannot close before it opened.

    Returns the violating rows. Zero rows = pass.

    Known data-entry / clock issue in mech_db. Severity is set to warn in
    the schema file: these are real orders with real labour hours attached,
    so we surface them rather than block the pipeline. Raised with Mechanical.
*/

select
    order_id,
    equipment_id,
    opened_at,
    closed_at,
    closed_at - opened_at as negative_duration

from {{ ref('stg_mech__maintenance_orders') }}

where closed_at < opened_at