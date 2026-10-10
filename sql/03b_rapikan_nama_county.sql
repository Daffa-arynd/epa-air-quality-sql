-- ============================================================
-- 03b_rapikan_nama_county.sql
-- Proyek : EPA Historical Air Quality (AQI harian 1980 - Mei 2021)
-- Isi    : merapikan spasi di awal/akhir nama state dan county
-- Temuan : 9 county di Alaska punya spasi di akhir nama
--          (contoh: 'Anchorage '); tidak ada county ganda (hasil 11J)
-- Aksi   : btrim() pada dim_wilayah saja. staging tidak diubah;
--          fact_aqi_harian tidak terpengaruh (memakai wilayah_id).
-- Urutan : jalankan setelah 03_buat_tabel_final.sql
-- Catatan: aman dijalankan ulang (kedua kali hasilnya UPDATE 0).
--          JALANKAN SATU PER SATU: highlight lalu F5.
-- ============================================================


-- ------------------------------------------------------------
-- A. Merapikan nama
-- Estimasi waktu: kurang dari 1 detik
-- Hasil yang diharapkan: UPDATE 9
-- ------------------------------------------------------------
UPDATE dim_wilayah
SET state_name  = btrim(state_name),
    county_name = btrim(county_name)
WHERE state_name  <> btrim(state_name)
   OR county_name <> btrim(county_name);


-- ------------------------------------------------------------
-- B. Verifikasi
-- Estimasi waktu: kurang dari 1 detik
-- Diharapkan: jumlah_county 1048, masih_berspasi 0, county_alaska 9
-- ------------------------------------------------------------
SELECT
    count(*)                                                       AS jumlah_county,
    count(*) FILTER (WHERE state_name  <> btrim(state_name)
                        OR county_name <> btrim(county_name))      AS masih_berspasi,
    count(*) FILTER (WHERE state_name = 'Alaska')                  AS county_alaska
FROM dim_wilayah;