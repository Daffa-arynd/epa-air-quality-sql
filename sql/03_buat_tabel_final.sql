-- ============================================================
-- 03_buat_tabel_final.sql
-- Proyek : EPA Historical Air Quality (AQI harian 1980 - Mei 2021)
-- Isi    : tabel final bertipe benar, dipecah jadi
--          dim_wilayah (1 baris per state+county)
--          fact_aqi_harian (1 baris per county per hari)
-- Sumber : staging.aqi_daily_raw (tidak diubah)
-- Catatan: JALANKAN SATU PER SATU: highlight bagian lalu F5.
--          Bagian INSERT (8B dan 8C) cukup dijalankan SEKALI.
-- ============================================================


-- ------------------------------------------------------------
-- 8A. Membuat tabel (aman dijalankan ulang karena IF NOT EXISTS)
-- Estimasi waktu: kurang dari 1 detik
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_wilayah (
    wilayah_id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    state_name     TEXT    NOT NULL,
    county_name    TEXT    NOT NULL,
    latitude       NUMERIC NOT NULL,
    longitude      NUMERIC NOT NULL,
    jenis_wilayah  TEXT    NOT NULL
        CHECK (jenis_wilayah IN ('state', 'dc', 'territory', 'luar_as')),
    UNIQUE (state_name, county_name)
);

CREATE TABLE IF NOT EXISTS fact_aqi_harian (
    wilayah_id          INTEGER NOT NULL REFERENCES dim_wilayah (wilayah_id),
    tanggal             DATE    NOT NULL,
    aqi                 INTEGER NOT NULL,
    category            TEXT    NOT NULL,
    defining_parameter  TEXT    NOT NULL,
    di_luar_skala       BOOLEAN NOT NULL,  -- TRUE jika AQI > 500 (di luar skala resmi EPA)
    PRIMARY KEY (wilayah_id, tanggal)
);


-- ------------------------------------------------------------
-- 8B. Mengisi dim_wilayah dari staging  (JALANKAN SEKALI)
-- Estimasi waktu: 30-90 detik
-- Hasil yang diharapkan: INSERT 0 1048
-- jenis_wilayah: state / dc / territory / luar_as
-- ------------------------------------------------------------
INSERT INTO dim_wilayah (state_name, county_name, latitude, longitude, jenis_wilayah)
SELECT
    state_name,
    county_name,
    latitude::numeric,
    longitude::numeric,
    CASE
        WHEN state_name = 'District Of Columbia'              THEN 'dc'
        WHEN state_name IN ('Puerto Rico', 'Virgin Islands')  THEN 'territory'
        WHEN state_name = 'Country Of Mexico'                 THEN 'luar_as'
        ELSE 'state'
    END
FROM staging.aqi_daily_raw
GROUP BY state_name, county_name, latitude, longitude
ORDER BY state_name, county_name;


-- ------------------------------------------------------------
-- 8C. Mengisi fact_aqi_harian dari staging  (JALANKAN SEKALI)
-- Estimasi waktu: 3-8 menit (query paling berat di proyek ini)
-- Hasil yang diharapkan: INSERT 0 10158527
-- ------------------------------------------------------------
INSERT INTO fact_aqi_harian (wilayah_id, tanggal, aqi, category, defining_parameter, di_luar_skala)
SELECT
    d.wilayah_id,
    s.date::date,
    s.aqi::int,
    s.category,
    s.defining_parameter,
    (s.aqi::int > 500)
FROM staging.aqi_daily_raw AS s
JOIN dim_wilayah AS d
  ON d.state_name  = s.state_name
 AND d.county_name = s.county_name;


-- ------------------------------------------------------------
-- 8D. Memperbarui statistik tabel supaya query berikutnya cepat
-- Estimasi waktu: 10-40 detik
-- ------------------------------------------------------------
ANALYZE dim_wilayah;
ANALYZE fact_aqi_harian;


-- ------------------------------------------------------------
-- 8E. Verifikasi jumlah baris (final harus sama dengan staging)
-- Estimasi waktu: 10-30 detik
-- Diharapkan: dim 1048, fact 10158527, staging 10158527, di_luar_skala 551
-- ------------------------------------------------------------
SELECT 'dim_wilayah' AS tabel, count(*) AS jumlah FROM dim_wilayah
UNION ALL
SELECT 'fact_aqi_harian', count(*) FROM fact_aqi_harian
UNION ALL
SELECT 'staging.aqi_daily_raw', count(*) FROM staging.aqi_daily_raw
UNION ALL
SELECT 'fact di_luar_skala = TRUE', count(*) FROM fact_aqi_harian WHERE di_luar_skala;


-- ------------------------------------------------------------
-- 8F. Verifikasi isi dim_wilayah per jenis wilayah
-- Estimasi waktu: kurang dari 1 detik
-- Diharapkan: state 1031, territory 14, luar_as 2, dc 1 (total 1048)
-- ------------------------------------------------------------
SELECT jenis_wilayah, count(*) AS jumlah_county
FROM dim_wilayah
GROUP BY jenis_wilayah
ORDER BY jumlah_county DESC;


-- ------------------------------------------------------------
-- 8G. Verifikasi isi data: total AQI dan rentang tanggal harus sama
--     antara staging dan tabel final
-- Estimasi waktu: 30-90 detik
-- Diharapkan: dua baris dengan total_aqi, tanggal_awal, tanggal_akhir sama
-- ------------------------------------------------------------
SELECT 'staging' AS sumber,
       sum(aqi::bigint) AS total_aqi,
       min(date)        AS tanggal_awal,
       max(date)        AS tanggal_akhir
FROM staging.aqi_daily_raw
UNION ALL
SELECT 'fact_aqi_harian',
       sum(aqi::bigint),
       min(tanggal)::text,
       max(tanggal)::text
FROM fact_aqi_harian;