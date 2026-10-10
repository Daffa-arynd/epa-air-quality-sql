# Data

Folder ini sengaja tidak berisi dataset. File CSV berukuran sekitar 669 MB, melewati batas 100 MB per file di GitHub, jadi dikecualikan lewat .gitignore.

## Cara mengunduh

1. Buka halaman dataset di Kaggle (perlu akun gratis):
   https://www.kaggle.com/datasets/threnjen/40-years-of-air-quality-index-from-the-epa-daily
2. Klik Download, lalu ekstrak file zip-nya.
3. Taruh file `aqi_daily_1980_to_2021.csv` di folder ini (`data/`), sehingga path-nya `data/aqi_daily_1980_to_2021.csv`.

Alternatif lewat Kaggle CLI (opsional, perlu API token Kaggle):

    kaggle datasets download -d threnjen/40-years-of-air-quality-index-from-the-epa-daily -p data --unzip

## Cek file yang benar

- Nama file: `aqi_daily_1980_to_2021.csv` (satu-satunya file di dataset ini)
- Ukuran: sekitar 669 MB
- Baris header: `State Name,Date,AQI,Category,Defining Parameter,Latitude,Longitude,County Name`
- Jumlah baris: 10.158.528 termasuk header (10.158.527 baris data)
- Periode: 1 Januari 1980 sampai 6 Mei 2021

Setelah file ada di sini, lanjutkan ke langkah 2 pada bagian "Cara Menjalankan" di README utama.

## Sumber dan lisensi

Data berasal dari EPA (AQI harian), dipublikasikan di Kaggle oleh pengguna threnjen. Lihat halaman dataset di Kaggle untuk lisensi dan ketentuan penggunaan.