/*
    INTERMEDIATE: point-in-time dwelling history per resident.

    Grain: one row per resident per dwelling occupancy period.

    Reconstructs where each resident lived at any point in time by turning
    discrete relocation events into date ranges. Each move begins a residency
    that ends when the next move occurs (lead), or is open-ended if it was
    the most recent move.

    The period BEFORE a resident's first move is derived from registered_at
    and their earliest relocation's from_dwelling_id.
*/

with residents as (

    select * from {{ ref('stg_census__residents') }}

),

relocations as (

    select * from {{ ref('stg_census__relocations') }}

),

-- each move starts a residency ending at the next move
moves as (

    select
        resident_id,
        to_dwelling_id                          as dwelling_id,
        relocated_at                            as valid_from,
        lead(relocated_at) over (
            partition by resident_id
            order by relocated_at
        )                                       as valid_to
    from relocations

),

-- the period before a resident's first move
first_move as (

    select distinct on (resident_id)
        resident_id,
        from_dwelling_id                        as dwelling_id,
        relocated_at                            as first_moved_at
    from relocations
    order by resident_id, relocated_at

),

original_residency as (

    select
        residents.resident_id,
        coalesce(first_move.dwelling_id, residents.dwelling_id) as dwelling_id,
        residents.registered_at                                 as valid_from,
        first_move.first_moved_at                               as valid_to
    from residents
    left join first_move
        on residents.resident_id = first_move.resident_id

),

combined as (

    select resident_id, dwelling_id, valid_from, valid_to from original_residency
    union all
    select resident_id, dwelling_id, valid_from, valid_to from moves

),

final as (

    select
        combined.resident_id,
        combined.dwelling_id,
        combined.valid_from,
        combined.valid_to,
        (combined.valid_to is null)     as is_current_residency,
        residents.resident_status,
        residents.birth_date
    from combined
    inner join residents
        on combined.resident_id = residents.resident_id
    where combined.dwelling_id is not null

)

select * from final