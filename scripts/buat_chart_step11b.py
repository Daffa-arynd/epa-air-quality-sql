# ============================================================
# buat_chart_step11b.py
# Chart 7: hari tidak sehat per polutan penentu, per dekade  (hasil 11G)
# Angka di bawah disalin dari hasil query, bukan dihitung ulang di Python.
# Cara jalan: python scripts/buat_chart_step11b.py  (hasil masuk folder images)
# Butuh: pip install matplotlib
# ============================================================
from pathlib import Path
import matplotlib.pyplot as plt

OUT = Path(__file__).resolve().parent.parent / "images"
OUT.mkdir(exist_ok=True)

TEKS = "#2F3B45"
ABU = "#8A949C"
plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "text.color": TEKS,
    "xtick.color": TEKS,
})


def ribuan(n):
    return f"{n:,}".replace(",", ".")


# Hasil 11G: hari_ozone, hari_so2, hari_pm25, hari_pm10, hari_no2, hari_co
data = {
    "1980-an":              [106241, 125998, 7, 826, 6491, 8371],
    "1990-an":              [128720, 66679, 1550, 1243, 2850, 797],
    "2000-an":              [102299, 25574, 16788, 2320, 682, 93],
    "2010-2020\n(11 tahun)": [39111, 8850, 14165, 2277, 82, 0],
}
label = list(data.keys())
ozon = [v[0] for v in data.values()]
so2 = [v[1] for v in data.values()]
pm25 = [v[2] for v in data.values()]
lain = [v[3] + v[4] + v[5] for v in data.values()]   # PM10 + NO2 + CO
total = [sum(v) for v in data.values()]
assert total == [247934, 201839, 147756, 64485] and sum(total) == 662014

lapisan = [
    ("Ozon", ozon, "#3F6A8A", "white"),
    ("SO2", so2, "#C9806A", "white"),
    ("PM2,5", pm25, "#D6C486", TEKS),
    ("Lainnya (PM10, NO2, CO)", lain, "#C4CCD2", TEKS),
]

fig, ax = plt.subplots(figsize=(8.4, 5.4), dpi=200)
x = range(len(label))
bawah = [0] * len(label)
for nama, nilai, warna, warna_teks in lapisan:
    ax.bar(x, nilai, bottom=bawah, color=warna, width=0.62, label=nama)
    for i, (v, b) in enumerate(zip(nilai, bawah)):
        if v >= 14000:
            ax.text(i, b + v / 2, ribuan(v), ha="center", va="center", fontsize=9, color=warna_teks)
    bawah = [b + v for b, v in zip(bawah, nilai)]

for i, t in enumerate(total):
    ax.text(i, t + 5000, ribuan(t), ha="center", va="bottom", fontsize=10.5, fontweight="bold", color=TEKS)

ax.set_xticks(list(x))
ax.set_xticklabels(label, fontsize=10)
ax.set_xlim(-0.6, 3.6)
ax.set_ylim(0, 285000)
ax.set_yticks([])
ax.tick_params(length=0)
for s in ("top", "right", "left"):
    ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color("#C9CFD4")
ax.legend(frameon=False, ncol=4, loc="upper center", bbox_to_anchor=(0.5, 1.0), fontsize=8.6,
          handlelength=1.0, columnspacing=1.2, labelcolor=TEKS)

fig.text(0.04, 0.945, "Berkurangnya hari SO2 menjelaskan 64% penurunan hari tidak sehat",
         fontsize=13, fontweight="bold", ha="left", color=TEKS)
fig.text(0.04, 0.895, "Jumlah county-hari dengan AQI > 100 per dekade menurut polutan penentu, 50 state, 1980-2020",
         fontsize=9, ha="left", color=ABU)
fig.text(0.04, 0.02, "Sumber: EPA Historical Air Quality (Kaggle, threnjen); diolah dengan PostgreSQL. SO2: 125.998 jadi 8.850 hari (-93%); ozon: 106.241 jadi 39.111 (-63%).\n"
         "PM2,5 kemungkinan baru terukur luas sekitar akhir 1990-an (dugaan), jadi kenaikannya sebagian mencerminkan pengukuran, bukan polusi baru.",
         fontsize=6.9, ha="left", color=ABU)
fig.subplots_adjust(left=0.05, right=0.97, top=0.85, bottom=0.17)
fig.savefig(OUT / "07_polutan_per_dekade.png")
plt.close(fig)
print("Selesai. Chart tersimpan di:", OUT)
