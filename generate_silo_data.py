#!/usr/bin/env python3
"""
Generate the synthetic Silo Operations raw dataset.

Three "source systems" plus one hand-maintained reference file:
    census_db/  - population register       (residents, dwellings, relocations)
    works_db/   - works department          (departments, job_assignments)
    mech_db/    - mechanical department     (equipment, generator_readings, maintenance_orders)
    seeds/      - level_zones.csv           (hand-maintained, goes in your dbt seeds/ folder)

Deliberate data-quality problems are planted throughout. See PLANTED_ISSUES at the bottom.
Stdlib only - no pip install required.
"""

import csv
import os
import random
from datetime import date, datetime, timedelta

random.seed(1440)  # deterministic: same data every run

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "silo_raw")
START = datetime(2022, 1, 1)
END = datetime(2025, 1, 1)

# --------------------------------------------------------------------------
# reference vocabulary
# --------------------------------------------------------------------------

N_LEVELS = 144

DEPARTMENTS = [
    # code,    name,             home_level, establishment
    ("MECH",  "Mechanical",           139, 210),
    ("IT",    "Information Tech",      34,  65),
    ("SUP",   "Supply",                72, 130),
    ("JUD",   "Judicial",              14,  40),
    ("SHER",  "Sheriff",                3,  35),
    ("FARM",  "Farms",                 26, 180),
    ("MED",   "Medical",               56,  70),
    ("CENS",  "Census",                18,  22),
    ("CAF",   "Cafeteria",              1,  55),
    ("SAN",   "Sanitation",           128,  60),
]
DEPT_CODES = [d[0] for d in DEPARTMENTS]

ROLES = {
    "MECH": ["Generator Technician", "Pump Operator", "Fabricator", "Shadow", "Chief Mechanic"],
    "IT":   ["Systems Technician", "Server Room Operator", "Shadow", "Head of IT"],
    "SUP":  ["Stores Clerk", "Requisitions Officer", "Porter", "Shadow"],
    "JUD":  ["Clerk", "Investigator", "Shadow", "Magistrate"],
    "SHER": ["Deputy", "Dispatcher", "Shadow", "Sheriff"],
    "FARM": ["Grower", "Irrigation Hand", "Harvest Lead", "Shadow"],
    "MED":  ["Nurse", "Physician", "Shadow", "Head Physician"],
    "CENS": ["Registrar", "Records Clerk", "Shadow"],
    "CAF":  ["Cook", "Server", "Dishwasher", "Shadow"],
    "SAN":  ["Waste Handler", "Filtration Technician", "Shadow"],
}

SHIFTS = ["DAY", "SWING", "NIGHT"]

GIVEN = """Juliette Holston Allison Bernard Lukas Martha Walker Knox Shirly Sims Marnes Jahns
Rebecca Carla Peter Gloria Hank Karma Rodney Cooper Nelson Terri Sandy Douglas Miles Corinne
Elise Hannah Jimmy Solo Charlotte Donald Helen Erik Anna Paul Darcy Amanda Lewis Kiel Vic
Rashida Emma Nolan Grace Otto Beatrice Silas Odette Marek Ivo Nadia Rune Cass Ilya Petra
Tomas Yara Osric Lena Bram Vesna Aldo Mira Kestrel Wren Foss Talia Rook Sable Dorn Isolde""".split()

FAMILY = """Nichols Becker Sinclair Wilkins Kyle Walker Parkins Trumbull Cordell Hines Marsh
Tate Grier Pell Vance Oakes Dunmore Rennick Halloway Sowerby Ashcroft Pryce Lomax Beckett
Farrow Cobb Rennie Slade Hallam Winters Quill Deane Marlow Ferris Strand Ives Bellamy Croft""".split()

EQUIPMENT_TYPES = [
    ("Main Generator",      "CRITICAL"),
    ("Backup Generator",    "CRITICAL"),
    ("Coolant Pump",        "CRITICAL"),
    ("Air Handler",         "HIGH"),
    ("Water Reclaimer",     "HIGH"),
    ("Stairwell Lift",      "MEDIUM"),
    ("Hydroponic Pump",     "MEDIUM"),
    ("Lighting Ballast",    "LOW"),
    ("Comms Relay",         "MEDIUM"),
    ("Waste Compactor",     "LOW"),
]


def rand_dt(start=START, end=END):
    delta = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, delta))


def write(subdir, filename, header, rows):
    path = os.path.join(OUT, subdir)
    os.makedirs(path, exist_ok=True)
    full = os.path.join(path, filename)
    with open(full, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"  {subdir}/{filename:<28} {len(rows):>7,} rows")


# ==========================================================================
# SEED: level_zones.csv  (hand-maintained reference data)
# ==========================================================================

def gen_level_zones():
    rows = []
    for lvl in range(1, N_LEVELS + 1):
        if lvl <= 20:
            zone, tier = "Up Top", 1
        elif lvl <= 100:
            zone, tier = "Mids", 2
        else:
            zone, tier = "Down Deep", 3
        # lift access only on landing levels
        has_lift = lvl % 12 == 0 or lvl in (1, 34, 56, 72)
        rows.append([lvl, zone, tier, str(has_lift).lower()])
    write("seeds", "level_zones.csv",
          ["level_number", "zone_name", "supply_tier", "has_lift_access"], rows)


# ==========================================================================
# census_db
# ==========================================================================

def gen_dwellings():
    rows = []
    dwelling_ids = []
    for lvl in range(1, N_LEVELS + 1):
        units = random.randint(6, 14)
        for u in range(1, units + 1):
            did = f"DW-{lvl:03d}-{u:02d}"
            dwelling_ids.append((did, lvl))
            dtype = random.choices(
                ["STANDARD", "FAMILY", "SINGLE", "DORMITORY"],
                weights=[50, 25, 20, 5])[0]
            cap = {"STANDARD": 3, "FAMILY": 5, "SINGLE": 1, "DORMITORY": 12}[dtype]
            rows.append([did, lvl, u, dtype, cap])
    write("census_db", "dwellings.csv",
          ["dwelling_id", "level_number", "unit_number", "dwelling_type", "capacity"], rows)
    return dwelling_ids


def gen_residents(dwelling_ids, n=4200):
    rows = []
    residents = []
    for i in range(1, n + 1):
        rid = f"RES-{i:05d}"
        did, lvl = random.choice(dwelling_ids)
        birth = date(random.randint(1955, 2018), random.randint(1, 12), random.randint(1, 28))
        registered = datetime(birth.year, birth.month, birth.day) + timedelta(days=random.randint(0, 14))

        # PLANTED MESS: inconsistent status casing + empty strings + nulls
        roll = random.random()
        if roll < 0.80:
            status = random.choice(["active", "Active", "ACTIVE", " active "])
        elif roll < 0.90:
            status = random.choice(["deceased", "Deceased"])
        elif roll < 0.97:
            status = random.choice(["relocated", "RELOCATED"])
        elif roll < 0.99:
            status = ""                     # empty string, not null
        else:
            status = "unregistered"          # value nobody documented

        updated = rand_dt(max(registered, START), END)
        synced = updated + timedelta(minutes=random.randint(1, 90))
        deleted = "true" if random.random() < 0.015 else "false"

        rows.append([
            rid,
            random.choice(GIVEN),
            random.choice(FAMILY),
            birth.isoformat(),
            did,
            status,
            registered.isoformat(sep=" "),
            updated.isoformat(sep=" "),
            synced.isoformat(sep=" "),
            deleted,
        ])
        residents.append((rid, did, lvl, birth))

    # PLANTED MESS: 45 duplicated rows, as a botched replication batch would produce
    for dup in random.sample(rows, 45):
        rows.append(list(dup))

    random.shuffle(rows)
    write("census_db", "residents.csv",
          ["resident_id", "given_name", "family_name", "birth_date", "dwelling_id",
           "status", "registered_at", "updated_at", "_synced_at", "_deleted"], rows)
    return residents


def gen_relocations(residents, dwelling_ids, n=6500):
    rows = []
    for i in range(1, n + 1):
        rid, did, lvl, _ = random.choice(residents)
        to_did, to_lvl = random.choice(dwelling_ids)
        when = rand_dt()
        reason = random.choices(
            ["PAIRING", "WORK ASSIGNMENT", "FAMILY", "MEDICAL", "SANCTION", ""],
            weights=[30, 30, 20, 10, 5, 5])[0]
        rows.append([f"REL-{i:06d}", rid, did, to_did, when.isoformat(sep=" "), reason])
    write("census_db", "relocations.csv",
          ["relocation_id", "resident_id", "from_dwelling_id", "to_dwelling_id",
           "relocated_at", "reason"], rows)


# ==========================================================================
# works_db
# ==========================================================================

def gen_departments():
    rows = [[c, n, lvl, est] for c, n, lvl, est in DEPARTMENTS]
    write("works_db", "departments.csv",
          ["department_code", "department_name", "home_level", "establishment_headcount"], rows)


def gen_job_assignments(residents, n=11000):
    rows = []
    working = [r for r in residents if (date.today().year - r[3].year) >= 16]
    for i in range(1, n + 1):
        rid = random.choice(working)[0]

        # PLANTED MESS: ~2% of assignments use a department code that
        # does not exist in departments.csv (a real unmapped-value scenario)
        if random.random() < 0.02:
            dept = random.choice(["RECYC", "SEC", "ARCH"])
            role = "Unclassified"
        else:
            dept = random.choice(DEPT_CODES)
            role = random.choice(ROLES[dept])

        started = rand_dt(START - timedelta(days=2000), END)
        if random.random() < 0.45:
            ended = started + timedelta(days=random.randint(30, 1400))
            ended_s = ended.isoformat(sep=" ") if ended < END else ""
        else:
            ended_s = ""                     # still current

        status = "ENDED" if ended_s else random.choice(["ACTIVE", "active"])
        updated = rand_dt(started, END) if started < END else started

        rows.append([
            f"JOB-{i:06d}", rid, dept, role,
            random.choice(SHIFTS),
            started.isoformat(sep=" "), ended_s, status,
            updated.isoformat(sep=" "),
        ])
    write("works_db", "job_assignments.csv",
          ["assignment_id", "resident_id", "department_code", "role_title", "shift_code",
           "started_at", "ended_at", "status", "updated_at"], rows)


# ==========================================================================
# mech_db
# ==========================================================================

def gen_equipment():
    rows = []
    eq = []
    i = 1
    for lvl in range(1, N_LEVELS + 1):
        for _ in range(random.randint(0, 2)):
            name, crit = random.choice(EQUIPMENT_TYPES)
            eid = f"EQ-{i:04d}"
            installed = date(random.randint(1998, 2023), random.randint(1, 12), random.randint(1, 28))
            rows.append([eid, name, lvl, crit, installed.isoformat()])
            eq.append((eid, lvl, crit))
            i += 1
    write("mech_db", "equipment.csv",
          ["equipment_id", "equipment_name", "level_number", "criticality", "installed_on"], rows)
    return eq


def gen_generator_readings():
    """Hourly readings, 6 generators, 3 years. ~157k rows - big enough to justify incremental."""
    rows = []
    gens = [
        ("GEN-01", 4200, 190),   # id, baseline kw, baseline temp*10
        ("GEN-02", 4100, 188),
        ("GEN-03", 3950, 195),
        ("GEN-BACKUP-A", 900, 140),
        ("GEN-BACKUP-B", 880, 142),
        ("GEN-AUX", 450, 120),
    ]
    t = START
    i = 1
    while t < END:
        hour_factor = 1.0 + 0.12 * (1 if 6 <= t.hour <= 21 else -1)
        for gid, base, temp in gens:
            # slow degradation over time + daily cycle + noise
            months = (t - START).days / 30.0
            output = base * hour_factor * (1 - 0.0009 * months) + random.gauss(0, base * 0.02)

            # PLANTED MESS: sensor faults
            r = random.random()
            if r < 0.0004:
                output = -abs(output)            # impossible negative reading
            elif r < 0.0010:
                output = ""                       # dropped reading (null)

            temp_c = temp / 10.0 + random.gauss(0, 1.8)
            vib = round(abs(random.gauss(2.4, 0.7)), 3)
            manual = "true" if random.random() < 0.01 else "false"

            # PLANTED MESS: late-arriving rows. Most sync within the hour,
            # but ~0.5% land days later - these break a naive incremental model.
            if random.random() < 0.005:
                synced = t + timedelta(days=random.randint(2, 9))
            else:
                synced = t + timedelta(minutes=random.randint(1, 55))

            rows.append([
                f"RD-{i:08d}", gid,
                t.isoformat(sep=" "),
                "" if output == "" else round(output, 2),
                round(temp_c, 2), vib, manual,
                synced.isoformat(sep=" "),
            ])
            i += 1
        t += timedelta(hours=1)

    # PLANTED MESS: 200 exact duplicate readings (double-sync)
    for dup in random.sample(rows, 200):
        rows.append(list(dup))

    write("mech_db", "generator_readings.csv",
          ["reading_id", "generator_id", "read_at", "output_kw", "temperature_c",
           "vibration_mm_s", "is_manual_entry", "_synced_at"], rows)


def gen_maintenance_orders(eq, n=3400):
    rows = []
    for i in range(1, n + 1):
        eid, lvl, crit = random.choice(eq)
        opened = rand_dt()
        if random.random() < 0.78:
            closed = opened + timedelta(hours=random.randint(2, 900))
            closed_s = closed.isoformat(sep=" ") if closed < END else ""
        else:
            closed_s = ""

        # PLANTED MESS: 1% of orders close before they open (clock/entry error)
        if closed_s and random.random() < 0.01:
            closed_s = (opened - timedelta(hours=random.randint(1, 48))).isoformat(sep=" ")

        status = "CLOSED" if closed_s else random.choice(["OPEN", "IN_PROGRESS", "BLOCKED"])
        priority = {"CRITICAL": "P1", "HIGH": "P2", "MEDIUM": "P3", "LOW": "P4"}[crit]
        hours = round(abs(random.gauss(6, 4)), 1) if closed_s else ""

        rows.append([
            f"MO-{i:06d}", eid,
            random.choice(["MECH", "MECH", "MECH", "SAN", "IT"]),
            opened.isoformat(sep=" "), closed_s, priority, status, hours,
        ])
    write("mech_db", "maintenance_orders.csv",
          ["order_id", "equipment_id", "department_code", "opened_at", "closed_at",
           "priority", "status", "labour_hours"], rows)


# ==========================================================================

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("Generating Silo Operations raw dataset...\n")

    gen_level_zones()
    dwelling_ids = gen_dwellings()
    residents = gen_residents(dwelling_ids)
    gen_relocations(residents, dwelling_ids)
    gen_departments()
    gen_job_assignments(residents)
    eq = gen_equipment()
    gen_generator_readings()
    gen_maintenance_orders(eq)

    print(f"\nWritten to: {OUT}")

PLANTED_ISSUES = """
1. residents.status      - four casings of 'active', plus empty strings and an
                           undocumented 'unregistered' value
2. residents             - 45 duplicated rows (botched replication batch)
3. residents._deleted    - ~1.5% soft-deleted rows that must be filtered in staging
4. job_assignments       - ~2% reference department codes absent from departments.csv
5. job_assignments.ended_at - empty string, not null, for current assignments
6. generator_readings    - negative outputs, null outputs, 200 exact duplicates
7. generator_readings    - ~0.5% arrive days after read_at (breaks naive incrementals)
8. maintenance_orders    - ~1% close before they open
9. relocations.reason    - empty strings mixed with real values
"""
