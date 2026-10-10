-- ============================================================
-- 01_setup_staging.sql
-- Proyek : EPA Historical Air Quality (AQI harian 1980-2021)
-- Isi    : schema staging + tabel mentah (semua kolom TEXT)
-- Catatan: urutan kolom HARUS sama dengan urutan kolom di CSV
-- ============================================================

CREATE SCHEMA IF NOT EXISTS staging;

CREATE TABLE IF NOT EXISTS staging.aqi_daily_raw (
    state_name          TEXT,
    date                TEXT,
    aqi                 TEXT,
    category            TEXT,
    defining_parameter  TEXT,
    latitude            TEXT,
    longitude           TEXT,
    county_name         TEXT
);