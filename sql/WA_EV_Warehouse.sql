-- ============================================
-- STAGING TABLES (raw data, loaded from CSV)
-- ============================================
DROP TABLE IF EXISTS "EVCoverage";
DROP TABLE IF EXISTS "Vehicle";
DROP TABLE IF EXISTS "Station";
DROP TABLE IF EXISTS "Geography";
DROP TABLE IF EXISTS "Calendar";
DROP TABLE IF EXISTS stg_ev_population;
DROP TABLE IF EXISTS stg_ev_stations;

-- ============================================
-- WASHINGTON STATE EV COVERAGE
-- Data Warehouse Script
-- Author: David Dupre
-- ============================================
-- ============================================
-- STEP 1: CREATE STAGING TABLES
-- ============================================

CREATE TABLE stg_ev_population (
    vin_10                  VARCHAR(10),
    county                  VARCHAR(100),
    city                    VARCHAR(100),
    state                   VARCHAR(10),
    postal_code             VARCHAR(10),
    model_year              INT,
    make                    VARCHAR(100),
    model                   VARCHAR(100),
    ev_type                 VARCHAR(100),
    cafv_eligibility        VARCHAR(200),
    electric_range          INT,
    legislative_district    VARCHAR(10),
    dol_vehicle_id          BIGINT,
    vehicle_location        TEXT,
    electric_utility        VARCHAR(200),
    census_tract_2020       VARCHAR(50)
);

CREATE TABLE stg_ev_stations (
    objectid                    TEXT,
    access_code                 TEXT,
    access_days_time            TEXT,
    access_detail_code          TEXT,
    cards_accepted              TEXT,
    date_last_confirmed         TEXT,
    expected_date               TEXT,
    fuel_type_code              TEXT,
    groups_with_access_code     TEXT,
    id                          TEXT,
    maximum_vehicle_class       TEXT,
    open_date                   TEXT,
    owner_type_code             TEXT,
    plus4                       TEXT,
    restricted_access           TEXT,
    status_code                 TEXT,
    facility_type               TEXT,
    station_name                TEXT,
    station_phone               TEXT,
    updated_at                  TEXT,
    geocode_status              TEXT,
    city                        TEXT,
    country                     TEXT,
    intersection_directions     TEXT,
    state                       TEXT,
    street_address              TEXT,
    zip                         TEXT,
    bd_blends                   TEXT,
    cng_dispenser_num           TEXT,
    cng_fill_type_code          TEXT,
    cng_has_rng                 TEXT,
    cng_psi                     TEXT,
    cng_renewable_source        TEXT,
    cng_total_compression       TEXT,
    cng_total_storage           TEXT,
    cng_vehicle_class           TEXT,
    e85_blender_pump            TEXT,
    e85_other_ethanol_blends    TEXT,
    ev_connector_types          TEXT,
    ev_dc_fast_num              TEXT,
    ev_level1_evse_num          TEXT,
    ev_level2_evse_num          TEXT,
    ev_network                  TEXT,
    ev_network_web              TEXT,
    ev_other_evse               TEXT,
    ev_pricing                  TEXT,
    ev_renewable_source         TEXT,
    ev_workplace_charging       TEXT,
    hy_is_retail                TEXT,
    hy_pressures                TEXT,
    hy_standards                TEXT,
    hy_status_link              TEXT,
    lng_has_rng                 TEXT,
    lng_renewable_source        TEXT,
    lng_vehicle_class           TEXT,
    lpg_nozzle_types            TEXT,
    lpg_primary                 TEXT,
    ng_fill_type_code           TEXT,
    ng_psi                      TEXT,
    ng_vehicle_class            TEXT,
    rd_blended_with_biodiesel   TEXT,
    rd_blends                   TEXT,
    rd_blends_fr                TEXT,
    rd_max_biodiesel_level      TEXT,
    nps_unit_name               TEXT,
    access_days_time_fr         TEXT,
    intersection_directions_fr  TEXT,
    bd_blends_fr                TEXT,
    groups_with_access_code_fr  TEXT,
    ev_pricing_fr               TEXT,
    federal_agency_id           TEXT,
    federal_agency_code         TEXT,
    federal_agency_name         TEXT,
    ev_network_ids_station      TEXT,
    ev_network_ids_posts        TEXT,
    longitude                   TEXT,
    latitude                    TEXT,
    x                           TEXT,
    y                           TEXT
);


-- ============================================
-- STEP 2: LOAD STAGING DATA
-- ============================================

COPY stg_ev_population
FROM '/tmp/ev_population.csv'
DELIMITER ','
CSV HEADER;

COPY stg_ev_stations
FROM '/tmp/alternative_fueling_stations.csv'
DELIMITER ','
CSV HEADER;

-- ============================================
-- STEP 3: CREATE DIMENSION TABLES
-- ============================================

-- VEHICLE
CREATE TABLE "Vehicle" (
    "VehicleKey"     SERIAL PRIMARY KEY,
    "VehicleID"      BIGINT,
    "VIN"            VARCHAR(10),
    "Make"           VARCHAR(100),
    "Model"          VARCHAR(100),
    "ModelYear"      INT,
    "EVType"         VARCHAR(100),
    "ElectricRange"  INT
);

-- STATION
CREATE TABLE "Station" (
    "StationKey"            SERIAL PRIMARY KEY,
    "StationID"             INT,
    "StationName"           VARCHAR(200),
    "EVNetwork"             VARCHAR(100),
    "Level1Ports"           INT,
    "Level2Ports"           INT,
    "DCFastPorts"           INT,
    "StatusCode"            VARCHAR(50),
    "EVConnectorTypes"      VARCHAR(200),
    "EVWorkPlaceCharging"   VARCHAR(10),
    "EVRenewableSource"     VARCHAR(100)
);

-- GEOGRAPHY
CREATE TABLE "Geography" (
    "GeographyKey"  SERIAL PRIMARY KEY,
    "ZipCode"       VARCHAR(10),
    "City"          VARCHAR(100),
    "County"        VARCHAR(100),
    "State"         VARCHAR(10),
    "Latitude"      DECIMAL(9,6),
    "Longitude"     DECIMAL(9,6)
);

-- CALENDAR
CREATE TABLE "Calendar" (
    "CalendarKey"   SERIAL PRIMARY KEY,
    "OpenDate"      DATE,
    "Year"          INT,
    "Month"         INT,
    "Quarter"       INT,
    "Season"        VARCHAR(20)
);

-- ============================================
-- STEP 4: CREATE FACT TABLE
-- ============================================

-- FACT TABLE
CREATE TABLE "EVCoverage" (
    "EVCount"           INT,
    "StationCount"      INT,
    "TotalChargers"     INT,
    "EVsPerCharger"     DECIMAL(10,2),
    "CoverageGapFlag"   SMALLINT,
    "StationKey"        INT REFERENCES "Station"("StationKey"),
    "CalendarKey"       INT REFERENCES "Calendar"("CalendarKey"),
    "GeographyKey"      INT REFERENCES "Geography"("GeographyKey"),
    "VehicleKey"        INT REFERENCES "Vehicle"("VehicleKey")
);

-- ============================================
-- STEP 5: POPULATE DIMENSION TABLES
-- ============================================

INSERT INTO "Geography" ("ZipCode", "City", "County", "State", "Latitude", "Longitude")
SELECT DISTINCT ON (postal_code)
    postal_code,
    city,
    county,
    state,
    NULL::DECIMAL(9,6),
    NULL::DECIMAL(9,6)
FROM stg_ev_population
WHERE state = 'WA'
ORDER BY postal_code, city;

INSERT INTO "Vehicle" ("VehicleID", "VIN", "Make", "Model", "ModelYear", "EVType", "ElectricRange")
SELECT DISTINCT
    CAST(dol_vehicle_id AS BIGINT),
    vin_10,
    make,
    model,
    CAST(model_year AS INT),
    ev_type,
    CAST(electric_range AS INT)
FROM stg_ev_population
WHERE state = 'WA';

INSERT INTO "Station" ("StationID", "StationName", "EVNetwork", "Level1Ports", "Level2Ports", "DCFastPorts", "StatusCode", "EVConnectorTypes", "EVWorkPlaceCharging", "EVRenewableSource")
SELECT 
    CAST(NULLIF(NULLIF(id,''),'NA') AS INT),
    station_name,
    ev_network,
    CAST(NULLIF(NULLIF(ev_level1_evse_num,''),'NA') AS INT),
    CAST(NULLIF(NULLIF(ev_level2_evse_num,''),'NA') AS INT),
    CAST(NULLIF(NULLIF(ev_dc_fast_num,''),'NA') AS INT),
    status_code,
    ev_connector_types,
    ev_workplace_charging,
    ev_renewable_source
FROM stg_ev_stations
WHERE fuel_type_code = 'ELEC'
AND state = 'WA';

INSERT INTO "Calendar" ("OpenDate", "Year", "Month", "Quarter", "Season")
SELECT DISTINCT
    CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE),
    EXTRACT(YEAR FROM CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE))::INT,
    EXTRACT(MONTH FROM CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE))::INT,
    EXTRACT(QUARTER FROM CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE))::INT,
    CASE 
        WHEN EXTRACT(MONTH FROM CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE)) IN (12, 1, 2)  THEN 'Winter'
        WHEN EXTRACT(MONTH FROM CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE)) IN (3, 4, 5)   THEN 'Spring'
        WHEN EXTRACT(MONTH FROM CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE)) IN (6, 7, 8)   THEN 'Summer'
        WHEN EXTRACT(MONTH FROM CAST(NULLIF(NULLIF(open_date, ''), 'NA') AS DATE)) IN (9, 10, 11) THEN 'Fall'
    END AS "Season"
FROM stg_ev_stations
WHERE fuel_type_code = 'ELEC'
AND state = 'WA'
AND NULLIF(NULLIF(open_date, ''), 'NA') IS NOT NULL;

-- ============================================
-- STEP 6: POPULATE FACT TABLE
-- ============================================

INSERT INTO "EVCoverage" ("EVCount", "StationCount", "TotalChargers", "EVsPerCharger", "CoverageGapFlag", "StationKey", "CalendarKey", "GeographyKey", "VehicleKey")
SELECT
    ev.ev_count,
    COALESCE(st.station_count, 0),
    COALESCE(st.total_chargers, 0),
    CASE 
        WHEN COALESCE(st.total_chargers, 0) = 0 THEN NULL
        ELSE ROUND(CAST(ev.ev_count AS DECIMAL) / st.total_chargers, 2)
    END,
    CASE 
        WHEN COALESCE(st.total_chargers, 0) = 0 THEN 1
        WHEN ROUND(CAST(ev.ev_count AS DECIMAL) / st.total_chargers, 2) > 10 THEN 1
        ELSE 0
    END,
    s."StationKey",
    cal."CalendarKey",
    g."GeographyKey",
    v."VehicleKey"
FROM (
    SELECT postal_code, COUNT(*) AS ev_count
    FROM stg_ev_population
    WHERE state = 'WA'
    GROUP BY postal_code
) ev
LEFT JOIN (
    SELECT 
        zip,
        COUNT(DISTINCT id) AS station_count,
        SUM(COALESCE(CAST(NULLIF(NULLIF(ev_level1_evse_num,''),'NA') AS INT), 0) +
            COALESCE(CAST(NULLIF(NULLIF(ev_level2_evse_num,''),'NA') AS INT), 0) +
            COALESCE(CAST(NULLIF(NULLIF(ev_dc_fast_num,''),'NA') AS INT), 0)) AS total_chargers,
        MIN(CAST(NULLIF(NULLIF(id,''),'NA') AS INT)) AS station_id
    FROM stg_ev_stations
    WHERE fuel_type_code = 'ELEC'
    AND state = 'WA'
    GROUP BY zip
) st ON ev.postal_code = st.zip
LEFT JOIN "Geography" g ON ev.postal_code = g."ZipCode"
LEFT JOIN "Station" s ON st.station_id = s."StationID"
LEFT JOIN (
    SELECT "CalendarKey" FROM "Calendar" ORDER BY "CalendarKey" LIMIT 1
) cal ON true
LEFT JOIN (
    SELECT "VehicleKey" FROM "Vehicle" ORDER BY "VehicleKey" LIMIT 1
) v ON true
WHERE g."GeographyKey" IS NOT NULL
GROUP BY ev.postal_code, ev.ev_count, st.station_count, st.total_chargers, 
         st.station_id, s."StationKey", cal."CalendarKey", g."GeographyKey", v."VehicleKey";

