{% snapshot snap_job_assignments %}

{{
    config(
        target_schema='snapshots',
        unique_key='assignment_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True
    )
}}

select * from {{ source('works_db', 'job_assignments') }}

{% endsnapshot %}