-- ============================================================
-- 02_cek_kualitas_data.sql
-- Proyek : EPA Historical Air Quality (AQI harian 1980 - Mei 2021)
-- Isi    : cek kualitas data pada tabel staging.aqi_daily_raw
-- Tabel  : staging.aqi_daily_raw (10.158.527 baris, semua kolom TEXT)
-- Catatan: semua query hanya SELECT (baca saja), aman diulang.
--          JALANKAN SATU PER SATU: highlight query lalu F5.
--          Jangan tekan F5 tanpa highlight, nanti semua query jalan
--          berurutan dan bisa makan belasan menit.
-- ============================================================


-- ------------------------------------------------------------
-- 6A. Jumlah nilai kosong (NULL atau string kosong) per kolom
-- Estimasi waktu: 20-60 detik
-- Temuan: semua 0, tidak ada nilai kosong
-- ------------------------------------------------------------
SELECT
    count(*)                                                                              AS total_baris,
    count(*) FILTER (WHERE state_name         IS NULL OR btrim(state_name)         = '')  AS state_kosong,
    count(*) FILTER (WHERE date               IS NULL OR btrim(date)               = '')  AS tanggal_kosong,
    count(*) FILTER (WHERE aqi                IS NULL OR btrim(aqi)                = '')  AS aqi_kosong,
    count(*) FILTER (WHERE category           IS NULL OR btrim(category)           = '')  AS kategori_kosong,
    count(*) FILTER (WHERE defining_parameter IS NULL OR btrim(defining_parameter) = '')  AS polutan_kosong,
    count(*) FILTER (WHERE latitude           IS NULL OR btrim(latitude)           = '')  AS lat_kosong,
    count(*) FILTER (WHERE longitude          IS NULL OR btrim(longitude)          = '')  AS lon_kosong,
    count(*) FILTER (WHERE county_name        IS NULL OR btrim(county_name)        = '')  AS county_kosong
FROM staging.aqi_daily_raw;


-- ------------------------------------------------------------
-- 6B. Format dan rentang nilai: tanggal, AQI, latitude, longitude
-- Estimasi waktu: 30-90 detik
-- Temuan: format valid semua; tanggal 1980-01-01 s/d 2021-05-06;
--         AQI min 0, max 20646 (di luar skala resmi 0-500, lihat 6E-6H)
-- ------------------------------------------------------------
SELECT
    count(*) FILTER (WHERE date !~ '^\d{4}-\d{2}-\d{2}$')   AS tanggal_format_aneh,
    min(date)                                               AS tanggal_awal,
    max(date)                                               AS tanggal_akhir,
    count(*) FILTER (WHERE aqi !~ '^-?\d+$')                AS aqi_bukan_angka,
    min(CASE WHEN aqi ~ '^-?\d+$' THEN aqi::int END)        AS aqi_min,
    max(CASE WHEN aqi ~ '^-?\d+$' THEN aqi::int END)        AS aqi_max,
    count(*) FILTER (WHERE latitude  !~ '^-?\d+(\.\d+)?$')  AS lat_bukan_angka,
    count(*) FILTER (WHERE longitude !~ '^-?\d+(\.\d+)?$')  AS lon_bukan_angka,
    min(CASE WHEN latitude  ~ '^-?\d+(\.\d+)?$' THEN latitude::numeric  END) AS lat_min,
    max(CASE WHEN latitude  ~ '^-?\d+(\.\d+)?$' THEN latitude::numeric  END) AS lat_max,
    min(CASE WHEN longitude ~ '^-?\d+(\.\d+)?$' THEN longitude::numeric END) AS lon_min,
    max(CASE WHEN longitude ~ '^-?\d+(\.\d+)?$' THEN longitude::numeric END) AS lon_max
FROM staging.aqi_daily_raw;


-- ------------------------------------------------------------
-- 6C. Nilai unik kolom category dan defining_parameter beserta jumlahnya
-- Estimasi waktu: 10-30 detik
-- Temuan: 6 kategori dan 6 polutan (Ozone, PM2.5, SO2, PM10, NO2, CO),
--         tidak ada ejaan ganda
-- ------------------------------------------------------------
SELECT 'category' AS kolom, category AS nilai, count(*) AS jumlah_baris
FROM staging.aqi_daily_raw
GROUP BY category
UNION ALL
SELECT 'defining_parameter', defining_parameter, count(*)
FROM staging.aqi_daily_raw
GROUP BY defining_parameter
ORDER BY kolom, jumlah_baris DESC;


-- ------------------------------------------------------------
-- 6D. Rentang AQI di tiap kategori (cek kategori cocok dengan angka AQI)
-- Estimasi waktu: 20-60 detik
-- Temuan: sesuai standar EPA; hanya Hazardous yang melewati 500
-- ------------------------------------------------------------
SELECT
    category,
    count(*)        AS jumlah_baris,
    min(aqi::int)   AS aqi_min,
    max(aqi::int)   AS aqi_max
FROM staging.aqi_daily_raw
WHERE aqi ~ '^-?\d+$'
GROUP BY category
ORDER BY aqi_min;


-- ------------------------------------------------------------
-- 6E. Ringkasan baris dengan AQI di atas 500 (di luar skala resmi EPA)
-- Estimasi waktu: 10-30 detik
-- Temuan: 551 baris, AQI 501 s/d 20646, tahun 1987 s/d 2021
-- ------------------------------------------------------------
SELECT
    count(*)       AS jumlah_baris,
    min(aqi::int)  AS aqi_min,
    max(aqi::int)  AS aqi_max,
    min(date)      AS tanggal_awal,
    max(date)      AS tanggal_akhir
FROM staging.aqi_daily_raw
WHERE aqi::int > 500;


-- ------------------------------------------------------------
-- 6F. 20 baris AQI tertinggi (lihat state, county, dan tanggalnya)
-- Estimasi waktu: 10-30 detik
-- Temuan: semuanya California (Inyo dan Mono), polutan PM10
-- ------------------------------------------------------------
SELECT state_name, county_name, date, aqi::int AS aqi, category, defining_parameter
FROM staging.aqi_daily_raw
WHERE aqi::int > 500
ORDER BY aqi::int DESC, date
LIMIT 20;


-- ------------------------------------------------------------
-- 6G. Cek duplikat: kombinasi (state_name, county_name, date) > 1 kali
-- Estimasi waktu: 1-3 menit
-- Temuan: 0 duplikat, kombinasi ini aman dijadikan kunci unik
-- ------------------------------------------------------------
SELECT
    count(*)                 AS jumlah_kombinasi_duplikat,
    coalesce(sum(n), 0)      AS total_baris_terlibat,
    coalesce(sum(n - 1), 0)  AS baris_kelebihan
FROM (
    SELECT state_name, county_name, date, count(*) AS n
    FROM staging.aqi_daily_raw
    GROUP BY state_name, county_name, date
    HAVING count(*) > 1
) AS dup;


-- ------------------------------------------------------------
-- 6H. Sebaran baris AQI > 500 per state dan polutan
-- Estimasi waktu: 10-30 detik
-- Temuan: total 551 baris; 522 di antaranya PM10, terbanyak California
-- ------------------------------------------------------------
SELECT
    state_name,
    defining_parameter,
    count(*)       AS jumlah_baris,
    max(aqi::int)  AS aqi_max
FROM staging.aqi_daily_raw
WHERE aqi::int > 500
GROUP BY state_name, defining_parameter
ORDER BY jumlah_baris DESC;


-- ------------------------------------------------------------
-- 6I. Daftar state/wilayah, jumlah baris, dan jumlah county
-- Estimasi waktu: 20-60 detik
-- Temuan: 54 nama = 50 state + District Of Columbia, Puerto Rico,
--         Virgin Islands, dan Country Of Mexico (bukan wilayah AS)
-- ------------------------------------------------------------
SELECT
    state_name,
    count(*)                     AS jumlah_baris,
    count(DISTINCT county_name)  AS jumlah_county
FROM staging.aqi_daily_raw
GROUP BY state_name
ORDER BY state_name;


-- ------------------------------------------------------------
-- 6J. Cakupan per tahun: jumlah baris, county, dan hari berbeda
-- Estimasi waktu: 30-90 detik
-- Temuan: county bermonitor naik 467 (1980) -> 1040 (2020);
--         2021 hanya 126 hari (sampai 6 Mei), jangan dipakai di tren tahunan
-- ------------------------------------------------------------
SELECT
    substr(date, 1, 4)                               AS tahun,
    count(*)                                         AS jumlah_baris,
    count(DISTINCT state_name || '|' || county_name) AS jumlah_county,
    count(DISTINCT date)                             AS jumlah_hari
FROM staging.aqi_daily_raw
GROUP BY substr(date, 1, 4)
ORDER BY tahun;


-- ------------------------------------------------------------
-- 6K. Nama county yang muncul di lebih dari satu state (10 teratas)
-- Estimasi waktu: 20-60 detik
-- Temuan: 109 nama county dipakai di banyak state (Washington di 13 state),
--         jadi kunci wilayah harus (state_name, county_name)
-- ------------------------------------------------------------
WITH shared AS (
    SELECT county_name, count(DISTINCT state_name) AS jumlah_state
    FROM staging.aqi_daily_raw
    GROUP BY county_name
    HAVING count(DISTINCT state_name) > 1
)
SELECT
    count(*) OVER ()  AS total_nama_county_bersama,
    county_name,
    jumlah_state
FROM shared
ORDER BY jumlah_state DESC, county_name
LIMIT 10;


-- ------------------------------------------------------------
-- 6L. Jumlah pasangan (latitude, longitude) berbeda per county
-- Estimasi waktu: 1-3 menit
-- Temuan: semua 1.048 county punya tepat 1 koordinat -> konsisten,
--         tabel dimensi wilayah boleh menyimpan 1 koordinat per county
-- ------------------------------------------------------------
WITH per_county AS (
    SELECT
        state_name,
        county_name,
        count(DISTINCT latitude || ',' || longitude) AS n_koordinat
    FROM staging.aqi_daily_raw
    GROUP BY state_name, county_name
)
SELECT
    n_koordinat,
    count(*) AS jumlah_county
FROM per_county
GROUP BY n_koordinat
ORDER BY n_koordinat;


-- ------------------------------------------------------------
-- 6M. 10 county dengan jumlah koordinat berbeda terbanyak
-- Estimasi waktu: 1-3 menit
-- Temuan: semuanya n_koordinat = 1 (konfirmasi hasil 6L)
-- ------------------------------------------------------------
SELECT
    state_name,
    county_name,
    count(DISTINCT latitude || ',' || longitude) AS n_koordinat,
    count(*)                                     AS jumlah_baris,
    min(date)                                    AS tanggal_awal,
    max(date)                                    AS tanggal_akhir
FROM staging.aqi_daily_raw
GROUP BY state_name, county_name
ORDER BY n_koordinat DESC, jumlah_baris DESC
LIMIT 10;