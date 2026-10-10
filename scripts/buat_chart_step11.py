# ============================================================
# buat_chart_step11.py
# Membuat 2 chart README dari hasil query di sql/06_analisis_wilayah_musim.sql
#   - Chart 5: pola musiman per bulan, dua periode            (hasil 11C)
#   - Chart 6: county yang bermasalah di setiap tahun 1980-2020 (hasil 11A)
# Angka di bawah disalin dari hasil query, bukan dihitung ulang di Python.
# Cara jalan: python scripts/buat_chart_step11.py  (hasil masuk folder images)
# Butuh: pip install matplotlib
# ============================================================
from pathlib import Path
import matplotlib.pyplot as plt

OUT = Path(__file__).resolve().parent.parent / "images"
OUT.mkdir(exist_ok=True)

TEKS = "#2F3B45"
ABU = "#8A949C"
BIRU = "#3F6A8A"
BIRU_MUDA = "#A3B4C2"
TERRACOTTA = "#B5694F"
plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "text.color": TEKS,
    "axes.labelcolor": TEKS,
    "xtick.color": ABU,
    "ytick.color": TEKS,
})


def koma(x, desimal=1):
    return f"{x:.{desimal}f}".replace(".", ",")


# ---------- Chart 5: pola musiman per bulan ----------
# Hasil 11C kolom persen_1980_1999 dan persen_2000_2020 (50 state, 1980-2020)
bulan = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
lama = [8.48, 7.74, 6.93, 8.51, 13.97, 19.32, 20.93, 19.13, 12.64, 7.90, 6.82, 7.41]
baru = [1.85, 1.46, 1.17, 2.37, 3.98, 6.86, 6.49, 6.37, 3.98, 1.60, 1.63, 1.65]
x = list(range(1, 13))

fig, ax = plt.subplots(figsize=(8.4, 5.0), dpi=200)
ax.axvspan(5.5, 8.5, color="#F2EFEA", zorder=0)
ax.text(7, 23.2, "Juni - Agustus", ha="center", fontsize=8.8, color=ABU)
ax.plot(x, lama, color=BIRU_MUDA, linewidth=2.4, marker="o", markersize=4.5, zorder=3)
ax.plot(x, baru, color=BIRU, linewidth=2.4, marker="o", markersize=4.5, zorder=3)

ax.text(7, 21.8, "Juli: " + koma(lama[6]) + "%", ha="center", fontsize=9.5, color=TEKS)
ax.text(6, baru[5] + 1.5, "Juni: " + koma(baru[5]) + "%", ha="center", fontsize=9.5, color=TEKS)
ax.text(12.35, lama[11], "1980-1999", ha="left", va="center", fontsize=9.5, color="#7F93A3")
ax.text(12.35, baru[11], "2000-2020", ha="left", va="center", fontsize=9.5, color=BIRU)

ax.set_xlim(0.6, 13.9)
ax.set_ylim(0, 24.5)
ax.set_xticks(x)
ax.set_xticklabels(bulan, fontsize=9.5)
ax.set_yticks([0, 5, 10, 15, 20])
ax.set_yticklabels([f"{v}%" for v in (0, 5, 10, 15, 20)], fontsize=9)
ax.tick_params(length=0)
ax.grid(axis="y", color="#E6EAED", linewidth=0.8)
ax.set_axisbelow(True)
for s in ("top", "right", "left"):
    ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color("#C9CFD4")

fig.text(0.04, 0.945, "Juni sampai Agustus selalu jadi bulan terburuk, sebelum dan sesudah 2000",
         fontsize=13, fontweight="bold", ha="left", color=TEKS)
fig.text(0.04, 0.895, "Persentase county-hari dengan AQI > 100 per bulan, 50 state, dibagi dua periode",
         fontsize=9, ha="left", color=ABU)
fig.text(0.04, 0.03, "Sumber: EPA Historical Air Quality (Kaggle, threnjen); diolah dengan PostgreSQL. Data 1980-2020.\n"
         "Jumlah county yang tercatat per bulan tidak sama (dugaan: sebagian monitor ozon hanya aktif di musim panas, belum diverifikasi).",
         fontsize=7.3, ha="left", color=ABU)
fig.subplots_adjust(left=0.08, right=0.97, top=0.85, bottom=0.14)
fig.savefig(OUT / "05_pola_musiman_per_bulan.png")
plt.close(fig)

# ---------- Chart 6: county bermasalah di setiap tahun ----------
# Hasil 11A: county dengan tahun_bermasalah = 41 dari 41 tahun, 10 dari 10 di 2011-2020
county = [
    ("Los Angeles, CA", 50.43),
    ("San Bernardino, CA", 49.50),
    ("Riverside, CA", 47.06),
    ("Kern, CA", 43.08),
    ("Fresno, CA", 38.25),
    ("Tulare, CA", 37.53),
    ("San Diego, CA", 28.90),
    ("Maricopa, AZ", 23.52),
    ("Stanislaus, CA", 16.09),
][::-1]

fig, ax = plt.subplots(figsize=(8.4, 5.0), dpi=200)
warna = [TERRACOTTA if "AZ" in n else "#8AA3B5" for n, _ in county]
bars = ax.barh([n for n, _ in county], [v for _, v in county], color=warna, height=0.66)
for b, (_, v) in zip(bars, county):
    ax.text(v + 0.8, b.get_y() + b.get_height() / 2, koma(v, 1) + "%",
            va="center", ha="left", fontsize=9.5, color=TEKS)

ax.set_xlim(0, 58)
ax.set_xticks([])
for s in ("top", "right", "bottom"):
    ax.spines[s].set_visible(False)
ax.spines["left"].set_color("#C9CFD4")
ax.tick_params(axis="y", length=0, labelsize=10)

fig.text(0.04, 0.945, "Sembilan county selalu melewati batas 5% hari tidak sehat sejak 1980",
         fontsize=12.5, fontweight="bold", ha="left", color=TEKS)
fig.text(0.04, 0.895, "Delapan di California, satu di Arizona. Persentase county-hari AQI > 100 selama 1980-2020 (41 dari 41 tahun di atas 5%)",
         fontsize=8.6, ha="left", color=ABU)
fig.text(0.04, 0.03, "Sumber: EPA Historical Air Quality (Kaggle, threnjen); diolah dengan PostgreSQL. Tahun bermasalah = minimal 5% hari AQI > 100.\n"
         "AQI county kemungkinan diambil dari monitor terburuk (belum diverifikasi), jadi county dengan banyak monitor bisa tampak lebih buruk.",
         fontsize=7.2, ha="left", color=ABU)
fig.subplots_adjust(left=0.20, right=0.97, top=0.85, bottom=0.14)
fig.savefig(OUT / "06_county_bermasalah_setiap_tahun.png")
plt.close(fig)

print("Selesai. Chart tersimpan di:", OUT)
