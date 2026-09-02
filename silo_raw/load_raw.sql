-- ===========================================================================
-- Silo Operations - raw layer loader
--
-- Run from the directory that CONTAINS silo_raw/, e.g.:
--     cd ~/projects
--     psql -d silo -f silo_raw/load_raw.sql
--
-- \copy is a psql client command, so paths are relative to where you run psql,
-- not to the server. This is the usual reason "file not found" appears here.
--
-- NOTE ON TYPES: columns that contain messy values are deliberately declared
-- as text. Real extract-and-load tools land data permissively and leave the
-- casting to you. If these were declared numeric/timestamp, the load would
-- reject the bad rows and you would never see the problem your staging layer
-- exists to solve.
-- ===========================================================================

create schema if not exists census_db;
create schema if not exists works_db;
create schema if not exists mech_db;

-- ---------------------------------------------------------------- census_db

drop table if exists census_db.dwellings;
create table census_db.dwellings (
    dwelling_id     text,
    level_number    integer,
    unit_number     integer,
    dwelling_type   text,
    capacity        integer
);

drop table if exists census_db.residents;
create table census_db.residents (
    resident_id     text,
    given_name      text,
    family_name     text,
    birth_date      date,
    dwelling_id     text,
    status          text,        -- messy: casing, empty strings, undocumented values
    registered_at   timestamp,
    updated_at      timestamp,
    _synced_at      timestamp,
    _deleted        boolean
);

drop table if exists census_db.relocations;
create table census_db.relocations (
    relocation_id     text,
    resident_id       text,
    from_dwelling_id  text,
    to_dwelling_id    text,
    relocated_at      timestamp,
    reason            text       -- messy: empty strings
);

-- ----------------------------------------------------------------- works_db

drop table if exists works_db.departments;
create table works_db.departments (
    department_code          text,
    department_name          text,
    home_level               integer,
    establishment_headcount  integer
);

drop table if exists works_db.job_assignments;
create table works_db.job_assignments (
    assignment_id    text,
    resident_id      text,
    department_code  text,       -- messy: codes absent from departments
    role_title       text,
    shift_code       text,
    started_at       timestamp,
    ended_at         text,       -- messy: empty string for current assignments
    status           text,       -- messy: casing
    updated_at       timestamp
);

-- ------------------------------------------------------------------ mech_db

drop table if exists mech_db.equipment;
create table mech_db.equipment (
    equipment_id    text,
    equipment_name  text,
    level_number    integer,
    criticality     text,
    installed_on    date
);

drop table if exists mech_db.generator_readings;
create table mech_db.generator_readings (
    reading_id       text,
    generator_id     text,
    read_at          timestamp,
    output_kw        text,       -- messy: nulls, negatives
    temperature_c    numeric(8,2),
    vibration_mm_s   numeric(8,3),
    is_manual_entry  boolean,
    _synced_at       timestamp   -- late arrivals live here
);

drop table if exists mech_db.maintenance_orders;
create table mech_db.maintenance_orders (
    order_id         text,
    equipment_id     text,
    department_code  text,
    opened_at        timestamp,
    closed_at        text,       -- messy: empty strings, and some precede opened_at
    priority         text,
    status           text,
    labour_hours     text        -- messy: empty strings
);

-- ------------------------------------------------------------------- load

\copy census_db.dwellings          from 'silo_raw/census_db/dwellings.csv'           with (format csv, header true);
\copy census_db.residents          from 'silo_raw/census_db/residents.csv'           with (format csv, header true);
\copy census_db.relocations        from 'silo_raw/census_db/relocations.csv'         with (format csv, header true);

\copy works_db.departments         from 'silo_raw/works_db/departments.csv'          with (format csv, header true);
\copy works_db.job_assignments     from 'silo_raw/works_db/job_assignments.csv'      with (format csv, header true);

\copy mech_db.equipment            from 'silo_raw/mech_db/equipment.csv'             with (format csv, header true);
\copy mech_db.generator_readings   from 'silo_raw/mech_db/generator_readings.csv'    with (format csv, header true);
\copy mech_db.maintenance_orders   from 'silo_raw/mech_db/maintenance_orders.csv'    with (format csv, header true);

-- ------------------------------------------------------------ indexes
-- The readings table is large enough that joins and incremental filters
-- benefit. Raw layers in the real world usually have these; add them so
-- your build times reflect reality.

create index on mech_db.generator_readings (read_at);
create index on mech_db.generator_readings (generator_id);
create index on mech_db.generator_readings (_synced_at);
create index on works_db.job_assignments (resident_id);
create index on census_db.residents (dwelling_id);

analyze;

-- ------------------------------------------------------------ verify

\echo ''
\echo 'Row counts:'
select 'census_db.residents'         as table_name, count(*) from census_db.residents
union all select 'census_db.dwellings',            count(*) from census_db.dwellings
union all select 'census_db.relocations',          count(*) from census_db.relocations
union all select 'works_db.departments',           count(*) from works_db.departments
union all select 'works_db.job_assignments',       count(*) from works_db.job_assignments
union all select 'mech_db.equipment',              count(*) from mech_db.equipment
union all select 'mech_db.generator_readings',     count(*) from mech_db.generator_readings
union all select 'mech_db.maintenance_orders',     count(*) from mech_db.maintenance_orders
order by 1;
