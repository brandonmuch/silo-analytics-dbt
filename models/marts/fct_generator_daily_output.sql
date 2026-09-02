/*
    MART: generator output by day.

    Grain: one row per generator per day.

    Answers Mechanical's question: is output degrading, and can we see it
    before something fails. Rolling averages smooth out daily noise so a
    genuine downward trend is distinguishable from a bad afternoon.
*/

with daily as (

    select * from {{ ref('int_generator_daily') }}

),

with_trend as (

    select
        *,

        avg(avg_output_kw) over (
            partition by generator_id
            order by reading_date
            rows between 6 preceding and current row
        ) as rolling_7d_avg_output_kw,

        avg(avg_output_kw) over (
            partition by generator_id
            order by reading_date
            rows between 29 preceding and current row
        ) as rolling_30d_avg_output_kw,

        first_value(avg_output_kw) over (
            partition by generator_id
            order by reading_date
        ) as baseline_output_kw,

        max(max_vibration_mm_s) over (
            partition by generator_id
            order by reading_date
            rows between 29 preceding and current row
        ) as rolling_30d_max_vibration

    from daily

),

final as (

    select
        generator_day_id,
        generator_id,
        reading_date,

        reading_count,
        valid_reading_count,
        faulty_reading_count,

        avg_output_kw,
        min_output_kw,
        max_output_kw,
        avg_temperature_c,
        max_vibration_mm_s,

        round(rolling_7d_avg_output_kw, 2)      as rolling_7d_avg_output_kw,
        round(rolling_30d_avg_output_kw, 2)     as rolling_30d_avg_output_kw,
        round(baseline_output_kw, 2)            as baseline_output_kw,
        round(rolling_30d_max_vibration, 3)     as rolling_30d_max_vibration,

        round(
            avg_output_kw / nullif(baseline_output_kw, 0),
            4
        )                                        as output_vs_baseline_pct,

        (avg_output_kw < baseline_output_kw * 0.975) as is_below_975pct_baseline,
        (faulty_reading_count > 0)                    as had_sensor_fault,
        (rolling_30d_max_vibration > 4.5)             as is_high_vibration

    from with_trend

)

select * from final