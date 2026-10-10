-- ============================================================
-- 04_query_dasar.sql
-- Proyek : EPA Historical Air Quality (AQI harian 1980 - Mei 2021)
-- Isi    : query dasar (rata-rata AQI per state, hari tidak sehat,
--          distribusi kategori)
-- Tabel  : fact_aqi_harian JOIN dim_wilayah
-- Catatan: semua query hanya SELECT, aman diulang.
--          JALANKAN SATU PER SATU: highlight query lalu F5.
-- Definisi: hari tidak sehat = AQI > 100 (kategori USG ke atas);
--          satuan hitung = county-hari (satu county pada satu hari).
-- ============================================================


-- ------------------------------------------------------------
-- 9A. Rata-rata AQI per state/wilayah (seluruh periode 1980 - Mei 2021)
-- Estimasi waktu: 20-60 detik
-- Cek: total jumlah_county_hari harus 10.158.527
-- Catatan: rata_aqi_tanpa_outlier membuang 551 baris AQI > 500
--          supaya terlihat seberapa besar pengaruh outlier
-- ------------------------------------------------------------
SELECT
    d.state_name,
    d.jenis_wilayah,
    count(DISTINCT d.county_name)                                  AS jumlah_county,
    count(*)                                                       AS jumlah_county_hari,
    round(avg(f.aqi), 1)                                           AS rata_aqi,
    round(avg(f.aqi) FILTER (WHERE NOT f.di_luar_skala), 1)        AS rata_aqi_tanpa_outlier
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
GROUP BY d.state_name, d.jenis_wilayah
ORDER BY rata_aqi DESC;


-- ------------------------------------------------------------
-- 9B. Jumlah hari tidak sehat (AQI > 100) per state/wilayah
-- Estimasi waktu: 20-60 detik
-- Cek: total hari_tidak_sehat harus 667.744
--      (USG 510.449 + Unhealthy 133.075 + Very Unhealthy 23.047 + Hazardous 1.173)
-- ------------------------------------------------------------
SELECT
    d.state_name,
    d.jenis_wilayah,
    count(*)                                              AS jumlah_county_hari,
    count(*) FILTER (WHERE f.aqi > 100)                   AS hari_tidak_sehat,
    round(100.0 * count(*) FILTER (WHERE f.aqi > 100)
                / count(*), 2)                            AS persen_tidak_sehat
FROM fact_aqi_harian AS f
JOIN dim_wilayah     AS d ON d.wilayah_id = f.wilayah_id
GROUP BY d.state_name, d.jenis_wilayah
ORDER BY persen_tidak_sehat DESC;


-- ------------------------------------------------------------
-- 9C. Distribusi kategori kualitas udara (seluruh data)
-- Estimasi waktu: 10-30 detik
-- Cek: jumlah per kategori harus sama dengan hasil 6C
-- ------------------------------------------------------------
SELECT
    category,
    count(*)                                              AS jumlah_county_hari,
    round(100.0 * count(*) / sum(count(*)) OVER (), 2)    AS persen
FROM fact_aqi_harian
GROUP BY category
ORDER BY min(aqi);