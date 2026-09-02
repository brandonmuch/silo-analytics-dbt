{{
    config(
        materialized='incremental',
        unique_key='generator_day_id',
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns'
    )
}}

/*
    INTERMEDIATE: daily generator output.

    Grain: one row per generator per day.

    INCREMENTAL with a 14-day lookback. Measured worst-case sync lag in this
    source is 9 days across 767 rows. A naive "read_at > max(read_at)" filter
    would skip every one of those permanently, silently.

    The lookback is only safe because unique_key drives a delete+insert:
    reprocessing the same window twice produces the same result.

    Filtering is on a DAY boundary because we group by day - a partial-day
    filter would write an incomplete daily total over a complete one.
*/

with readings as (

    select * from {{ ref('stg_mech__generator_readings') }}

    {% if is_incremental() %}

    where read_at >= (
        select coalesce(max(reading_date), '1900-01-01'::date) - interval '14 days'
        from {{ this }}
    )

    {% endif %}

),

daily as (

    select
        {{ dbt_utils.generate_surrogate_key(['generator_id', "cast(read_at as date)"]) }} as generator_day_id,

        generator_id,
        cast(read_at as date)                                as reading_date,

        count(*)                                             as reading_count,
        count(output_kw)                                     as valid_reading_count,
        count(*) filter (where is_faulty_reading)            as faulty_reading_count,

        round(avg(output_kw), 2)                             as avg_output_kw,
        round(min(output_kw), 2)                             as min_output_kw,
        round(max(output_kw), 2)                             as max_output_kw,

        round(avg(temperature_c), 2)                         as avg_temperature_c,
        round(max(vibration_mm_s), 3)                        as max_vibration_mm_s,

        max(synced_at)                                       as last_synced_at

    from readings
    group by 1, 2, 3

)

select * from daily