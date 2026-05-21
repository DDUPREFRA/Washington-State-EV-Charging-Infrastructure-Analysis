-- ============================================
-- SECTION 1: COVERAGE GAP ANALYSIS
-- ============================================

--1.Top 10 best served zip codes 
SELECT 
    g."ZipCode",
    g."City",
    g."County",
    e."EVCount",
    e."TotalChargers",
    e."EVsPerCharger"
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
WHERE e."CoverageGapFlag" = 0
ORDER BY e."EVsPerCharger" ASC
LIMIT 10;

--2.Top 10 most undeserved zip codes
SELECT 
    g."ZipCode",
    g."City",
    g."County",
    e."EVCount",
    e."StationCount",
    e."TotalChargers",
    e."EVsPerCharger"
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
WHERE e."CoverageGapFlag" = 1
AND e."TotalChargers" > 0
ORDER BY e."EVsPerCharger" DESC
LIMIT 10;

--3.Zip codes with EVs but zero chargers
SELECT 
    g."ZipCode",
    g."City",
    g."County",
    e."EVCount"
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
WHERE e."TotalChargers" = 0
ORDER BY e."EVCount" DESC
LIMIT 10;


-- ============================================
-- SECTION 2: COUNTY LEVEL ANALYSIS
-- ============================================

--4.Coverage gap by county
SELECT 
    g."County",
    SUM(e."EVCount") AS total_evs,
    SUM(e."TotalChargers") AS total_chargers,
    ROUND(CAST(SUM(e."EVCount") AS DECIMAL) / NULLIF(SUM(e."TotalChargers"), 0), 2) AS evs_per_charger,
    SUM(CASE WHEN e."CoverageGapFlag" = 1 THEN 1 ELSE 0 END) AS underserved_zips
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
GROUP BY g."County"
ORDER BY evs_per_charger DESC;

--5.EV adoption by county
SELECT 
    g."County",
    SUM(e."EVCount") AS total_evs,
    COUNT(e."GeographyKey") AS zip_count,
    ROUND(CAST(SUM(e."EVCount") AS DECIMAL) / COUNT(e."GeographyKey"), 0) AS avg_evs_per_zip
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
GROUP BY g."County"
ORDER BY total_evs DESC;

--6.Counties least served for DC fast charging 
SELECT 
    g."County",
    SUM(s."DCFastPorts") AS total_fast_chargers,
    SUM(e."EVCount") AS total_evs,
    ROUND(CAST(SUM(e."EVCount") AS DECIMAL) / NULLIF(SUM(s."DCFastPorts"), 0), 2) AS evs_per_fast_charger
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
JOIN "Station" s ON e."StationKey" = s."StationKey"
GROUP BY g."County"
ORDER BY evs_per_fast_charger DESC NULLS LAST
LIMIT 10;

--7.Counties best served for DC fast charging
SELECT 
    g."County",
    SUM(COALESCE(s."DCFastPorts",0)) AS total_fast_chargers,
    SUM(e."EVCount") AS total_evs,
    ROUND(CAST(SUM(e."EVCount") AS DECIMAL) / 
        NULLIF(SUM(COALESCE(s."DCFastPorts",0)), 0), 2) AS evs_per_fast_charger
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
LEFT JOIN "Station" s ON e."StationKey" = s."StationKey"
GROUP BY g."County"
HAVING SUM(COALESCE(s."DCFastPorts",0)) > 0
ORDER BY evs_per_fast_charger ASC
LIMIT 10;

-- ============================================
-- SECTION 3: VEHICLE ANALYSIS
-- ============================================

--8.EV type breakdown (BEV vs PHEV)
SELECT 
    v."EVType",
    COUNT(*) AS vehicle_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM "Vehicle" v
GROUP BY v."EVType"
ORDER BY vehicle_count DESC;

--9.Top 10 EV makes in Washington
SELECT 
    v."Make",
    COUNT(*) AS vehicle_count
FROM "Vehicle" v
GROUP BY v."Make"
ORDER BY vehicle_count DESC
LIMIT 10;

--10.Average electric range by EV make
SELECT 
    v."Make",
    ROUND(AVG(v."ElectricRange"), 0) AS avg_range_miles,
    COUNT(*) AS vehicle_count
FROM "Vehicle" v
WHERE v."ElectricRange" > 0
GROUP BY v."Make"
ORDER BY avg_range_miles DESC
LIMIT 10;

-- ============================================
-- SECTION 4: CHARGING NETWORK ANALYSIS
-- ============================================

--11.Charging network market share
SELECT 
    s."EVNetwork",
    COUNT(*) AS station_count,
    SUM(COALESCE(s."Level1Ports",0) + COALESCE(s."Level2Ports",0) + COALESCE(s."DCFastPorts",0)) AS total_ports,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS market_share_pct
FROM "Station" s
WHERE s."EVNetwork" IS NOT NULL
GROUP BY s."EVNetwork"
ORDER BY station_count DESC
LIMIT 10;

--12.Networks – DC fast vs slow chargers
SELECT 
    s."EVNetwork",
    SUM(COALESCE(s."DCFastPorts",0)) AS dc_fast_ports,
    SUM(COALESCE(s."Level2Ports",0)) AS level2_ports,
    SUM(COALESCE(s."Level1Ports",0)) AS level1_ports,
    SUM(COALESCE(s."Level1Ports",0) + COALESCE(s."Level2Ports",0) + COALESCE(s."DCFastPorts",0)) AS total_ports,
    ROUND(CAST(SUM(COALESCE(s."DCFastPorts",0)) AS DECIMAL) / 
        NULLIF(SUM(COALESCE(s."Level1Ports",0) + COALESCE(s."Level2Ports",0) + COALESCE(s."DCFastPorts",0)), 0) * 100, 2) AS fast_charger_pct
FROM "Station" s
WHERE s."EVNetwork" IS NOT NULL
GROUP BY s."EVNetwork"
ORDER BY dc_fast_ports DESC
LIMIT 10;


--13.Connector types dominating Washington State
SELECT 
    TRIM(UNNEST(STRING_TO_ARRAY(s."EVConnectorTypes", ' '))) AS connector_type,
    COUNT(*) AS station_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM "Station" s
WHERE s."EVConnectorTypes" IS NOT NULL
AND s."EVConnectorTypes" != ''
GROUP BY connector_type
ORDER BY station_count DESC;


-- ============================================
-- SECTION 5: GREEN ENERGY ANALYSIS
-- ============================================

--14.Share of stations running on renewable energy
SELECT 
    CASE 
        WHEN s."EVRenewableSource" IS NULL 
        OR s."EVRenewableSource" = '' 
        OR s."EVRenewableSource" = 'NA' THEN 'Non-Renewable'
        ELSE 'Renewable'
    END AS energy_type,
    COUNT(*) AS station_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM "Station" s
GROUP BY energy_type
ORDER BY station_count DESC;

--15.Counties with highest concentration of green charging
SELECT 
    g."County",
    COUNT(DISTINCT e."GeographyKey") AS total_zip_codes,
    COUNT(DISTINCT s."StationKey") AS total_stations,
    SUM(CASE WHEN s."EVRenewableSource" IS NOT NULL 
        AND s."EVRenewableSource" != '' 
        AND s."EVRenewableSource" != 'NA' THEN 1 ELSE 0 END) AS renewable_stations,
    ROUND(SUM(CASE WHEN s."EVRenewableSource" IS NOT NULL 
        AND s."EVRenewableSource" != '' 
        AND s."EVRenewableSource" != 'NA' THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(COUNT(DISTINCT s."StationKey"), 0), 2) AS renewable_pct
FROM "EVCoverage" e
JOIN "Geography" g ON e."GeographyKey" = g."GeographyKey"
LEFT JOIN "Station" s ON e."StationKey" = s."StationKey"
GROUP BY g."County"
ORDER BY renewable_pct DESC NULLS LAST;

-- ============================================
-- SECTION 6: INFRASTRUCTURE GROWTH
-- ============================================

SELECT 
    EXTRACT(YEAR FROM CAST(NULLIF(NULLIF(open_date,''),'NA') AS DATE))::INT AS year,
    COUNT(*) AS stations_opened,
    SUM(COUNT(*)) OVER (ORDER BY EXTRACT(YEAR FROM CAST(NULLIF(NULLIF(open_date,''),'NA') AS DATE))::INT) AS cumulative_stations
FROM stg_ev_stations
WHERE fuel_type_code = 'ELEC'
AND state = 'WA'
AND NULLIF(NULLIF(open_date,''),'NA') IS NOT NULL
GROUP BY EXTRACT(YEAR FROM CAST(NULLIF(NULLIF(open_date,''),'NA') AS DATE))::INT
ORDER BY year ASC;