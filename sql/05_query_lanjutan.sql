-- ============================================================
-- 05_query_lanjutan.sql
-- Proyek : EPA Historical Air Quality (AQI harian 1980 - Mei 2021)
-- Isi    : query lanjutan (JOIN, CTE, RANK, LAG, regr_slope,
--          rata-rata bergerak 30 hari, PERCENTILE_CONT)
-- Tabel  : fact_aqi_harian JOIN dim_wilayah
-- Catatan: semua query hanya SELECT, aman diulang.
--          JALANKAN SATU PER SATU: highlight query lalu F5.
-- Aturan : analisis tahunan memakai 1980-2020 saja (2021 hanya
--          sampai 6 Mei); analisis state memakai 50 state saja
--          (jenis_wilayah = 'state').
-- Definisi: hari tidak sehat = AQI > 100; satuan = county-hari.
-- ============================================================


-- ------------------------------------------------------------
-- 10A. Peringkat state per tahun (5 teratas pada tahun terpilih)
-- Teknik : JOIN, CTE, window function RANK() OVER (PARTITION BY)
-- Syarat : state-tahun minimal 700 county-hari (setara 2 county
--          dengan data setahun penuh) supaya peringkat tidak
--          dipengaruhi state yang cuma punya 1 monitor
-- Estimasi waktu: 30-90 detik
-- ------------------------------------------------------------
WITH state_tahun AS (
    SELECT
        d.state_name,
        extract(year FROM f.tanggal)::int       AS tahun,
        count(*)                                AS county_hari,
        count(*) FILTER (WHERE f.aqi > 100)     AS hari_tidak_sehat
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.jenis_wilayah = 'state'
      AND f.tanggal < DATE '2021-01-01'
    GROUP BY d.state_name, extract(year FROM f.tanggal)
    HAVING count(*) >= 700
),
ranking AS (
    SELECT
        state_name,
        tahun,
        county_hari,
        100.0 * hari_tidak_sehat / county_hari AS persen,
        rank() OVER (
            PARTITION BY tahun
            ORDER BY 100.0 * hari_tidak_sehat / county_hari DESC
        ) AS peringkat
    FROM state_tahun
)
SELECT
    tahun,
    peringkat,
    state_name,
    round(persen, 2) AS persen_tidak_sehat,
    county_hari
FROM ranking
WHERE tahun IN (1980, 1990, 2000, 2010, 2020)
  AND peringkat <= 5
ORDER BY tahun, peringkat;


-- ------------------------------------------------------------
-- 10B. Tren nasional per tahun + perubahan year-over-year
-- Teknik : CTE, LAG() OVER (ORDER BY)
-- Cek    : kolom rata_hari_per_county menunjukkan apakah cakupan
--          hari per county berubah (indikasi monitor musiman)
-- Estimasi waktu: 30-90 detik
-- ------------------------------------------------------------
WITH nasional_tahun AS (
    SELECT
        extract(year FROM f.tanggal)::int       AS tahun,
        count(DISTINCT f.wilayah_id)            AS jumlah_county,
        count(*)                                AS county_hari,
        count(*) FILTER (WHERE f.aqi > 100)     AS hari_tidak_sehat,
        avg(f.aqi)                              AS rata_aqi
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.jenis_wilayah = 'state'
      AND f.tanggal < DATE '2021-01-01'
    GROUP BY extract(year FROM f.tanggal)
),
hitung AS (
    SELECT
        tahun,
        jumlah_county,
        round(county_hari::numeric / jumlah_county, 0) AS rata_hari_per_county,
        hari_tidak_sehat,
        100.0 * hari_tidak_sehat / county_hari         AS persen,
        rata_aqi
    FROM nasional_tahun
)
SELECT
    tahun,
    jumlah_county,
    rata_hari_per_county,
    hari_tidak_sehat,
    round(persen, 2)                                          AS persen_tidak_sehat,
    round(persen - LAG(persen) OVER (ORDER BY tahun), 2)      AS perubahan_yoy_poin,
    round(rata_aqi, 1)                                        AS rata_aqi,
    round(rata_aqi - LAG(rata_aqi) OVER (ORDER BY tahun), 1)  AS perubahan_rata_aqi
FROM hitung
ORDER BY tahun;


-- ------------------------------------------------------------
-- 10C. Kemiringan tren per state (regr_slope)
-- Teknik : CTE, regr_slope, regr_r2
-- Arti   : kemiringan_poin_per_dekade = perubahan persen hari
--          tidak sehat tiap 10 tahun (negatif = membaik).
--          r2 mendekati 1 = tren rapi; mendekati 0 = tren acak.
-- Syarat : state punya minimal 20 tahun data (>= 700 county-hari)
-- Estimasi waktu: 30-90 detik
-- ------------------------------------------------------------
WITH state_tahun AS (
    SELECT
        d.state_name,
        extract(year FROM f.tanggal)::int       AS tahun,
        count(*)                                AS county_hari,
        count(*) FILTER (WHERE f.aqi > 100)     AS hari_tidak_sehat
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.jenis_wilayah = 'state'
      AND f.tanggal < DATE '2021-01-01'
    GROUP BY d.state_name, extract(year FROM f.tanggal)
    HAVING count(*) >= 700
),
persen_tahun AS (
    SELECT state_name, tahun, 100.0 * hari_tidak_sehat / county_hari AS persen
    FROM state_tahun
)
SELECT
    state_name,
    count(*)                                                      AS tahun_data,
    round((regr_slope(persen, tahun) * 10)::numeric, 2)           AS kemiringan_poin_per_dekade,
    round(regr_r2(persen, tahun)::numeric, 2)                     AS r2,
    round(avg(persen) FILTER (WHERE tahun <= 1989), 2)            AS persen_1980an,
    round(avg(persen) FILTER (WHERE tahun >= 2011), 2)            AS persen_2011_2020
FROM persen_tahun
GROUP BY state_name
HAVING count(*) >= 20
ORDER BY kemiringan_poin_per_dekade;


-- ------------------------------------------------------------
-- 10D. Tren nasional dengan kontrol: hanya Mei-September dan
--      membandingkan "semua county" vs "panel konsisten"
-- Teknik : beberapa CTE, UNION ALL, regr_slope, regr_r2
-- Kontrol: Mei-September = musim saat semua jenis monitor aktif,
--          jadi perubahan jumlah monitor musiman tidak menggeser hasil.
-- Panel  : county dengan minimal 30 tahun data musim panas
--          (tiap tahun minimal 120 dari 153 hari)
-- Estimasi waktu: 1-3 menit
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
      AND extract(month FROM f.tanggal) BETWEEN 5 AND 9
    GROUP BY f.wilayah_id, extract(year FROM f.tanggal)
),
valid AS (
    SELECT * FROM county_tahun WHERE hari_data >= 120
),
panel AS (
    SELECT wilayah_id FROM valid GROUP BY wilayah_id HAVING count(*) >= 30
),
gabungan AS (
    SELECT 'semua county' AS kelompok, wilayah_id, tahun, hari_data, hari_tidak_sehat
    FROM valid
    UNION ALL
    SELECT 'panel konsisten', wilayah_id, tahun, hari_data, hari_tidak_sehat
    FROM valid
    WHERE wilayah_id IN (SELECT wilayah_id FROM panel)
),
per_tahun AS (
    SELECT
        kelompok,
        tahun,
        count(*)                                        AS jumlah_county,
        100.0 * sum(hari_tidak_sehat) / sum(hari_data)  AS persen
    FROM gabungan
    GROUP BY kelompok, tahun
)
SELECT
    kelompok,
    min(jumlah_county)                                          AS county_min_per_tahun,
    max(jumlah_county)                                          AS county_maks_per_tahun,
    round(avg(persen) FILTER (WHERE tahun BETWEEN 1980 AND 1984), 2) AS persen_1980_1984,
    round(avg(persen) FILTER (WHERE tahun BETWEEN 2016 AND 2020), 2) AS persen_2016_2020,
    round((regr_slope(persen, tahun) * 10)::numeric, 2)         AS kemiringan_poin_per_dekade,
    round(regr_r2(persen, tahun)::numeric, 2)                   AS r2
FROM per_tahun
GROUP BY kelompok
ORDER BY kelompok;


-- ------------------------------------------------------------
-- 10E. Rata-rata bergerak 30 hari: Los Angeles County, California, 2020
-- Teknik : window function AVG() OVER (RANGE BETWEEN INTERVAL ...)
-- Catatan: dihitung dengan jendela 30 hari kalender (tanggal t-29
--          sampai t), bukan 30 baris, supaya hari yang hilang tidak
--          menggeser jendela. Ditampilkan tanggal 15 tiap bulan saja.
-- Estimasi waktu: kurang dari 10 detik
-- ------------------------------------------------------------
SELECT
    tanggal,
    aqi,
    round(rata_bergerak_30h, 1) AS rata_bergerak_30h
FROM (
    SELECT
        f.tanggal,
        f.aqi,
        avg(f.aqi) OVER (
            ORDER BY f.tanggal
            RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT ROW
        ) AS rata_bergerak_30h
    FROM fact_aqi_harian AS f
    JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
    WHERE d.state_name  = 'California'
      AND d.county_name = 'Los Angeles'
      AND f.tanggal BETWEEN DATE '2019-12-03' AND DATE '2020-12-31'
) AS t
WHERE tanggal >= DATE '2020-01-01'
  AND extract(day FROM tanggal) = 15
ORDER BY tanggal;


-- ------------------------------------------------------------
-- 10F. Median, persentil 90, dan persentil 95 AQI per state
-- Teknik : PERCENTILE_CONT() WITHIN GROUP (ORDER BY)
-- Tujuan : ukuran yang tahan terhadap outlier AQI > 500
--          (seluruh periode 1980 - Mei 2021, 50 state)
-- Estimasi waktu: 1-3 menit
-- ------------------------------------------------------------
SELECT
    d.state_name,
    count(*)                                                              AS county_hari,
    round(avg(f.aqi), 1)                                                  AS rata_aqi,
    round((percentile_cont(0.5)  WITHIN GROUP (ORDER BY f.aqi))::numeric, 1) AS median_aqi,
    round((percentile_cont(0.9)  WITHIN GROUP (ORDER BY f.aqi))::numeric, 1) AS p90_aqi,
    round((percentile_cont(0.95) WITHIN GROUP (ORDER BY f.aqi))::numeric, 1) AS p95_aqi
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
WHERE d.jenis_wilayah = 'state'
GROUP BY d.state_name
ORDER BY p95_aqi DESC;

-- ------------------------------------------------------------
-- 10G. Cek silang: total hari tidak sehat 50 state harus cocok dengan 9B
-- Estimasi waktu: 20-60 detik
-- Diharapkan: 662014 (1980-2020) + 266 (2021) = 662280
-- ------------------------------------------------------------
SELECT
    count(*) FILTER (WHERE f.tanggal <  DATE '2021-01-01' AND f.aqi > 100) AS tidak_sehat_1980_2020,
    count(*) FILTER (WHERE f.tanggal >= DATE '2021-01-01' AND f.aqi > 100) AS tidak_sehat_2021,
    count(*) FILTER (WHERE f.aqi > 100)                                    AS total
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
WHERE d.jenis_wilayah = 'state';


-- ------------------------------------------------------------
-- 10H. Cek loncatan April-Mei 2020 di Los Angeles County:
--      ringkasan per bulan (jumlah hari data, rata-rata, polutan dominan)
-- Estimasi waktu: kurang dari 10 detik
-- Diharapkan: 12 baris; hari_data tiap bulan sekitar 28-31
-- ------------------------------------------------------------
SELECT
    extract(month FROM f.tanggal)::int                          AS bulan,
    count(*)                                                    AS hari_data,
    round(avg(f.aqi), 1)                                        AS rata_aqi,
    min(f.aqi)                                                  AS aqi_min,
    max(f.aqi)                                                  AS aqi_max,
    count(*) FILTER (WHERE f.aqi > 100)                         AS hari_tidak_sehat,
    mode() WITHIN GROUP (ORDER BY f.defining_parameter)         AS polutan_dominan
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
WHERE d.state_name  = 'California'
  AND d.county_name = 'Los Angeles'
  AND f.tanggal BETWEEN DATE '2020-01-01' AND DATE '2020-12-31'
GROUP BY extract(month FROM f.tanggal)
ORDER BY bulan;