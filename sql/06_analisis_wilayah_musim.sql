-- ============================================================
-- 06_analisis_wilayah_musim.sql
-- Proyek : EPA Historical Air Quality (AQI harian 1980 - Mei 2021)
-- Isi    : county yang konsisten melewati AQI 100, pola musiman
--          per bulan, dan polutan penentu per wilayah dan musim
-- Tabel  : fact_aqi_harian JOIN dim_wilayah
-- Catatan: semua query hanya SELECT, aman diulang.
--          JALANKAN SATU PER SATU: highlight query lalu F5.
-- Aturan : 1980-2020 saja (2021 hanya sampai 6 Mei); 50 state saja.
-- Definisi: tahun bermasalah = county-tahun dengan >= 150 hari data
--          dan >= 5% hari AQI > 100. Hari tidak sehat = AQI > 100.
--          Musim: Dingin (Des-Feb), Semi (Mar-Mei), Panas (Jun-Agu),
--          Gugur (Sep-Nov).
-- ============================================================


-- ------------------------------------------------------------
-- 11A. 25 county yang paling konsisten melewati AQI 100
-- Teknik : CTE bertingkat, FILTER, agregasi per county
-- Syarat : county punya minimal 30 tahun data yang valid
-- Estimasi waktu: 1-2 menit
-- ------------------------------------------------------------
WITH county_tahun AS (
    SELECT
        f.wilayah_id,
        extract(year FROM f.tanggal)::int       AS tahun,
        count(*)                                AS hari_data,
        count(*) FILTER (WHERE f.aqi > 100)     AS hari_tidak_sehat
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.jenis_wilayah = 'state'
      AND f.tanggal < DATE '2021-01-01'
    GROUP BY f.wilayah_id, extract(year FROM f.tanggal)
    HAVING count(*) >= 150
)
SELECT
    d.state_name,
    d.county_name,
    count(*)                                                              AS tahun_data,
    count(*) FILTER (WHERE c.hari_tidak_sehat::numeric / c.hari_data >= 0.05) AS tahun_bermasalah,
    count(*) FILTER (WHERE c.hari_tidak_sehat::numeric / c.hari_data >= 0.05
                       AND c.tahun >= 2011)                               AS tahun_bermasalah_2011_2020,
    sum(c.hari_tidak_sehat)                                               AS hari_tidak_sehat_total,
    round(100.0 * sum(c.hari_tidak_sehat) / sum(c.hari_data), 2)          AS persen_tidak_sehat
FROM county_tahun AS c
JOIN dim_wilayah  AS d ON d.wilayah_id = c.wilayah_id
GROUP BY d.state_name, d.county_name
HAVING count(*) >= 30
ORDER BY tahun_bermasalah DESC, persen_tidak_sehat DESC
LIMIT 25;


-- ------------------------------------------------------------
-- 11B. Berapa banyak county yang masuk tiap kelompok "tahun bermasalah"
-- Teknik : CTE, CASE, GROUP BY
-- Estimasi waktu: 1-2 menit
-- ------------------------------------------------------------
WITH county_tahun AS (
    SELECT
        f.wilayah_id,
        extract(year FROM f.tanggal)::int       AS tahun,
        count(*)                                AS hari_data,
        count(*) FILTER (WHERE f.aqi > 100)     AS hari_tidak_sehat
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.jenis_wilayah = 'state'
      AND f.tanggal < DATE '2021-01-01'
    GROUP BY f.wilayah_id, extract(year FROM f.tanggal)
    HAVING count(*) >= 150
),
per_county AS (
    SELECT
        wilayah_id,
        count(*) FILTER (WHERE hari_tidak_sehat::numeric / hari_data >= 0.05) AS tahun_bermasalah
    FROM county_tahun
    GROUP BY wilayah_id
    HAVING count(*) >= 30
)
SELECT
    CASE
        WHEN tahun_bermasalah = 0  THEN '0 tahun'
        WHEN tahun_bermasalah <= 4 THEN '1-4 tahun'
        WHEN tahun_bermasalah <= 9 THEN '5-9 tahun'
        WHEN tahun_bermasalah <= 19 THEN '10-19 tahun'
        ELSE '20 tahun atau lebih'
    END                 AS kelompok_tahun_bermasalah,
    count(*)            AS jumlah_county
FROM per_county
GROUP BY 1
ORDER BY min(tahun_bermasalah);


-- ------------------------------------------------------------
-- 11C. Pola musiman nasional per bulan, dipisah dua periode
-- Teknik : FILTER, agregasi per bulan
-- Catatan: monitor ozon banyak yang hanya aktif di musim panas,
--          jadi jumlah county_hari per bulan tidak sama
-- Estimasi waktu: 30-90 detik
-- ------------------------------------------------------------
SELECT
    extract(month FROM f.tanggal)::int                                  AS bulan,
    count(*)                                                            AS county_hari,
    round(avg(f.aqi), 1)                                                AS rata_aqi,
    round(100.0 * count(*) FILTER (WHERE f.aqi > 100) / count(*), 2)    AS persen_tidak_sehat,
    round(100.0 * count(*) FILTER (WHERE f.aqi > 100 AND f.tanggal <  DATE '2000-01-01')
          / nullif(count(*) FILTER (WHERE f.tanggal <  DATE '2000-01-01'), 0), 2) AS persen_1980_1999,
    round(100.0 * count(*) FILTER (WHERE f.aqi > 100 AND f.tanggal >= DATE '2000-01-01')
          / nullif(count(*) FILTER (WHERE f.tanggal >= DATE '2000-01-01'), 0), 2) AS persen_2000_2020
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
WHERE d.jenis_wilayah = 'state'
  AND f.tanggal < DATE '2021-01-01'
GROUP BY extract(month FROM f.tanggal)
ORDER BY bulan;


-- ------------------------------------------------------------
-- 11D. Polutan penentu pada hari tidak sehat, per musim (nasional)
-- Teknik : CTE, tabel nilai (VALUES), window function SUM() OVER (PARTITION BY)
-- Estimasi waktu: 30-90 detik
-- Cek    : total hari_tidak_sehat semua baris = 662.014
-- ------------------------------------------------------------
WITH nama_musim (urutan, musim) AS (
    VALUES (1, 'Dingin (Des-Feb)'), (2, 'Semi (Mar-Mei)'),
           (3, 'Panas (Jun-Agu)'),  (4, 'Gugur (Sep-Nov)')
),
dasar AS (
    SELECT
        CASE
            WHEN extract(month FROM f.tanggal) IN (12, 1, 2) THEN 1
            WHEN extract(month FROM f.tanggal) IN (3, 4, 5)  THEN 2
            WHEN extract(month FROM f.tanggal) IN (6, 7, 8)  THEN 3
            ELSE 4
        END                    AS urutan,
        f.defining_parameter
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.jenis_wilayah = 'state'
      AND f.aqi > 100
      AND f.tanggal < DATE '2021-01-01'
)
SELECT
    n.musim,
    x.defining_parameter,
    x.hari_tidak_sehat,
    round(100.0 * x.hari_tidak_sehat / sum(x.hari_tidak_sehat) OVER (PARTITION BY x.urutan), 1) AS persen_dalam_musim
FROM (
    SELECT urutan, defining_parameter, count(*) AS hari_tidak_sehat
    FROM dasar
    GROUP BY urutan, defining_parameter
) AS x
JOIN nama_musim AS n ON n.urutan = x.urutan
ORDER BY x.urutan, x.hari_tidak_sehat DESC;


-- ------------------------------------------------------------
-- 11E. Polutan penentu pada hari tidak sehat, per state (seluruh periode)
-- Teknik : FILTER, agregasi per state
-- Tujuan : menguji dugaan SO2 di Hawaii dan melihat state lain
-- Estimasi waktu: 30-90 detik
-- Cek    : total hari_tidak_sehat semua baris = 662.014
-- ------------------------------------------------------------
SELECT
    d.state_name,
    count(*)                                                                            AS hari_tidak_sehat,
    round(100.0 * count(*) FILTER (WHERE f.defining_parameter = 'Ozone') / count(*), 1) AS persen_ozone,
    round(100.0 * count(*) FILTER (WHERE f.defining_parameter = 'PM2.5') / count(*), 1) AS persen_pm25,
    round(100.0 * count(*) FILTER (WHERE f.defining_parameter = 'PM10')  / count(*), 1) AS persen_pm10,
    round(100.0 * count(*) FILTER (WHERE f.defining_parameter = 'SO2')   / count(*), 1) AS persen_so2,
    round(100.0 * count(*) FILTER (WHERE f.defining_parameter = 'NO2')   / count(*), 1) AS persen_no2,
    round(100.0 * count(*) FILTER (WHERE f.defining_parameter = 'CO')    / count(*), 1) AS persen_co
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
WHERE d.jenis_wilayah = 'state'
  AND f.aqi > 100
  AND f.tanggal < DATE '2021-01-01'
GROUP BY d.state_name
ORDER BY hari_tidak_sehat DESC;


-- ------------------------------------------------------------
-- 11F. Polutan penentu per musim di tiga state berisiko (2011-2020)
-- Teknik : CTE, window function, filter ambang 5%
-- State  : Hawaii, California, Arizona
-- Estimasi waktu: 10-30 detik
-- ------------------------------------------------------------
WITH nama_musim (urutan, musim) AS (
    VALUES (1, 'Dingin (Des-Feb)'), (2, 'Semi (Mar-Mei)'),
           (3, 'Panas (Jun-Agu)'),  (4, 'Gugur (Sep-Nov)')
),
dasar AS (
    SELECT
        d.state_name,
        CASE
            WHEN extract(month FROM f.tanggal) IN (12, 1, 2) THEN 1
            WHEN extract(month FROM f.tanggal) IN (3, 4, 5)  THEN 2
            WHEN extract(month FROM f.tanggal) IN (6, 7, 8)  THEN 3
            ELSE 4
        END                    AS urutan,
        f.defining_parameter
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.state_name IN ('Hawaii', 'California', 'Arizona')
      AND f.aqi > 100
      AND f.tanggal >= DATE '2011-01-01'
      AND f.tanggal <  DATE '2021-01-01'
),
hitung AS (
    SELECT
        state_name,
        urutan,
        defining_parameter,
        count(*) AS hari_tidak_sehat,
        round(100.0 * count(*) / sum(count(*)) OVER (PARTITION BY state_name, urutan), 1) AS persen_dalam_musim
    FROM dasar
    GROUP BY state_name, urutan, defining_parameter
)
SELECT
    h.state_name,
    n.musim,
    h.defining_parameter,
    h.hari_tidak_sehat,
    h.persen_dalam_musim
FROM hitung AS h
JOIN nama_musim AS n ON n.urutan = h.urutan
WHERE h.persen_dalam_musim >= 5
ORDER BY h.state_name, h.urutan, h.hari_tidak_sehat DESC;

-- ------------------------------------------------------------
-- 11G. Hari tidak sehat per polutan penentu, per dekade (50 state)
-- Tujuan : menguji apakah penurunan hari tidak sehat didorong polutan
--          tertentu (misalnya SO2) dan kapan polutan itu berkurang
-- Estimasi waktu: 30-90 detik
-- Cek    : jumlah kolom hari_tidak_sehat semua baris = 662.014
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN extract(year FROM f.tanggal) < 1990 THEN '1980-an'
        WHEN extract(year FROM f.tanggal) < 2000 THEN '1990-an'
        WHEN extract(year FROM f.tanggal) < 2010 THEN '2000-an'
        ELSE '2010-2020'
    END                                                              AS periode,
    count(*)                                                         AS hari_tidak_sehat,
    count(*) FILTER (WHERE f.defining_parameter = 'Ozone')           AS hari_ozone,
    count(*) FILTER (WHERE f.defining_parameter = 'SO2')             AS hari_so2,
    count(*) FILTER (WHERE f.defining_parameter = 'PM2.5')           AS hari_pm25,
    count(*) FILTER (WHERE f.defining_parameter = 'PM10')            AS hari_pm10,
    count(*) FILTER (WHERE f.defining_parameter = 'NO2')             AS hari_no2,
    count(*) FILTER (WHERE f.defining_parameter = 'CO')              AS hari_co
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
WHERE d.jenis_wilayah = 'state'
  AND f.aqi > 100
  AND f.tanggal < DATE '2021-01-01'
GROUP BY 1
ORDER BY 1;


-- ------------------------------------------------------------
-- 11H. 15 county paling berisiko pada 2016-2020 beserta polutan dominan
-- Syarat : minimal 1.500 county-hari (sekitar 82% dari 1.826 hari)
--          supaya county dengan monitor musiman tidak ikut dibandingkan
-- Estimasi waktu: 30-90 detik
-- Diharapkan: 15 baris
-- ------------------------------------------------------------
SELECT
    d.state_name,
    d.county_name,
    count(*)                                                    AS hari_data,
    count(*) FILTER (WHERE f.aqi > 100)                         AS hari_tidak_sehat,
    round(100.0 * count(*) FILTER (WHERE f.aqi > 100)
                / count(*), 2)                                  AS persen_tidak_sehat,
    mode() WITHIN GROUP (ORDER BY f.defining_parameter)
        FILTER (WHERE f.aqi > 100)                              AS polutan_dominan
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
WHERE d.jenis_wilayah = 'state'
  AND f.tanggal >= DATE '2016-01-01'
  AND f.tanggal <  DATE '2021-01-01'
GROUP BY d.state_name, d.county_name
HAVING count(*) >= 1500
ORDER BY persen_tidak_sehat DESC
LIMIT 15;

-- ------------------------------------------------------------
-- 11I. Cek spasi di awal/akhir nama state dan county di dim_wilayah
-- Estimasi waktu: kurang dari 1 detik
-- Diharapkan: beberapa baris saja (nama dibungkus [ ] supaya spasi terlihat)
-- ------------------------------------------------------------
SELECT
    wilayah_id,
    state_name,
    '[' || county_name || ']'  AS county_dibungkus_kurung,
    length(county_name)        AS panjang_nama
FROM dim_wilayah
WHERE county_name <> btrim(county_name)
   OR state_name  <> btrim(state_name);


-- ------------------------------------------------------------
-- 11J. Cek county ganda setelah nama dirapikan (spasi dan huruf besar-kecil)
-- Estimasi waktu: kurang dari 1 detik
-- Diharapkan: 0 baris (kalau ada baris, satu county terpecah jadi dua)
-- ------------------------------------------------------------
SELECT
    btrim(state_name)                                                AS state_name,
    lower(regexp_replace(btrim(county_name), '\s+', ' ', 'g'))       AS county_dirapikan,
    count(*)                                                         AS jumlah_baris_dim
FROM dim_wilayah
GROUP BY 1, 2
HAVING count(*) > 1;