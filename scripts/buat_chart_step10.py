# ============================================================
# buat_chart_step10.py
# Membuat 2 chart README dari hasil query di sql/05_query_lanjutan.sql
#   - Chart 3: tren nasional persen hari tidak sehat 1980-2020  (hasil 10B)
#   - Chart 4: 1980-an vs 2011-2020 untuk state terpilih        (hasil 10C)
# Angka di bawah disalin dari hasil query, bukan dihitung ulang di Python.
# Cara jalan: python scripts/buat_chart_step10.py  (hasil masuk folder images)
# Butuh: pip install matplotlib
# ============================================================
from pathlib import Path
import matplotlib.pyplot as plt

OUT = Path(__file__).resolve().parent.parent / "images"
OUT.mkdir(exist_ok=True)

TEKS = "#2F3B45"
ABU = "#8A949C"
BIRU = "#5C7C99"
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


# ---------- Chart 3: tren nasional ----------
# Hasil 10B kolom persen_tidak_sehat, 50 state, 1980-2020
persen = [18.90, 16.90, 15.57, 16.85, 15.88, 15.01, 14.08, 14.60, 16.00, 11.48,
          11.05, 11.02, 8.15, 8.91, 8.85, 9.03, 7.90, 7.67, 10.08, 10.51,
          7.49, 7.43, 8.43, 5.77, 4.00, 6.12, 4.75, 5.45, 3.31, 1.89,
          2.64, 2.93, 3.46, 1.64, 1.39, 1.50, 1.42, 1.65, 1.72, 0.78, 1.48]
tahun = list(range(1980, 2021))
assert len(persen) == len(tahun) == 41

fig, ax = plt.subplots(figsize=(8.4, 5.0), dpi=200)
ax.plot(tahun, persen, color=BIRU, linewidth=2.2, solid_capstyle="round")
for t, p, tx, ty, ha in [(1980, 18.90, 1980.7, 19.3, "left"),
                         (2020, 1.48, 2020.4, 3.4, "right")]:
    ax.plot([t], [p], "o", color=TERRACOTTA, markersize=5.5, zorder=3)
    ax.text(tx, ty, f"{t}: {koma(p, 1)}%", fontsize=9.5, ha=ha, color=TEKS)

ax.set_xlim(1979, 2021.2)
ax.set_ylim(0, 21)
ax.set_yticks([0, 5, 10, 15, 20])
ax.set_yticklabels([f"{v}%" for v in (0, 5, 10, 15, 20)], fontsize=9)
ax.set_xticks(range(1980, 2021, 10))
ax.tick_params(axis="x", labelsize=9.5, length=0)
ax.tick_params(axis="y", length=0)
ax.grid(axis="y", color="#E6EAED", linewidth=0.8)
ax.set_axisbelow(True)
for s in ("top", "right", "left"):
    ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color("#C9CFD4")

fig.text(0.04, 0.945, "Hari-county tidak sehat turun dari 18,9% (1980) ke 1,5% (2020)",
         fontsize=13.5, fontweight="bold", ha="left", color=TEKS)
fig.text(0.04, 0.895, "Persentase county-hari dengan AQI > 100 per tahun, 50 state. Tren tetap turun setelah dikontrol (lihat README).",
         fontsize=8.8, ha="left", color=ABU)
fig.text(0.04, 0.03, "Sumber: EPA Historical Air Quality (Kaggle, threnjen); diolah dengan PostgreSQL. 2021 tidak ditampilkan (data hanya sampai 6 Mei).",
         fontsize=7.3, ha="left", color=ABU)
fig.subplots_adjust(left=0.08, right=0.97, top=0.85, bottom=0.12)
fig.savefig(OUT / "03_tren_nasional_hari_tidak_sehat.png")
plt.close(fig)

# ---------- Chart 4: 1980-an vs 2011-2020 ----------
# Hasil 10C kolom persen_1980an dan persen_2011_2020
data = [  # (state, 1980-an, 2011-2020)
    ("Hawaii", 10.29, 16.01),
    ("California", 17.86, 8.53),
    ("Arizona", 26.97, 6.21),
    ("Utah", 19.59, 2.91),
    ("Connecticut", 20.48, 2.88),
    ("Ohio", 19.10, 1.47),
    ("Indiana", 27.85, 1.35),
    ("Tennessee", 20.50, 1.22),
    ("West Virginia", 31.44, 0.60),
][::-1]

fig, ax = plt.subplots(figsize=(8.4, 5.6), dpi=200)
for i, (nama, a, b) in enumerate(data):
    sorot = nama in ("Hawaii", "California", "Arizona")
    warna_akhir = TERRACOTTA if sorot else BIRU
    ax.plot([a, b], [i, i], color="#CBD3D9", linewidth=2.4, zorder=1)
    ax.scatter([a], [i], s=70, color="#BFC8CF", zorder=2)
    ax.scatter([b], [i], s=80, color=warna_akhir, zorder=3)
    if b > a:   # Hawaii naik
        ax.text(a - 0.9, i, koma(a, 1) + "%", ha="right", va="center", fontsize=9, color=ABU)
        ax.text(b + 0.9, i, koma(b, 1) + "%", ha="left", va="center", fontsize=9.5, color=TEKS)
    else:
        ax.text(a + 0.9, i, koma(a, 1) + "%", ha="left", va="center", fontsize=9, color=ABU)
        ax.text(b - 0.9, i, koma(b, 1) + "%", ha="right", va="center", fontsize=9.5, color=TEKS)

ax.set_yticks(range(len(data)))
ax.set_yticklabels([d[0] for d in data], fontsize=10)
ax.set_xlim(-4.5, 36)
ax.set_ylim(-0.7, len(data) - 0.3 + 0.9)
ax.set_xticks([0, 10, 20, 30])
ax.set_xticklabels(["0%", "10%", "20%", "30%"], fontsize=9)
ax.tick_params(axis="both", length=0)
ax.grid(axis="x", color="#E6EAED", linewidth=0.8)
ax.set_axisbelow(True)
for s in ("top", "right", "left"):
    ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color("#C9CFD4")

# keterangan titik
ax.scatter([22.0], [len(data) - 0.05], s=55, color="#BFC8CF")
ax.text(22.9, len(data) - 0.05, "1980-an", va="center", fontsize=8.8, color=ABU)
ax.scatter([28.0], [len(data) - 0.05], s=60, color=BIRU)
ax.text(28.9, len(data) - 0.05, "2011-2020", va="center", fontsize=8.8, color=ABU)

fig.text(0.04, 0.945, "Hanya Hawaii, California, dan Arizona yang masih di atas 6%",
         fontsize=13, fontweight="bold", ha="left", color=TEKS)
fig.text(0.04, 0.895, "Persentase county-hari dengan AQI > 100, rata-rata 1980-an vs 2011-2020. 9 state terpilih: 3 tertinggi + yang paling membaik",
         fontsize=8.5, ha="left", color=ABU)
fig.text(0.04, 0.03, "Sumber: EPA Historical Air Quality (Kaggle, threnjen); diolah dengan PostgreSQL. Rata-rata sederhana dari persen tahunan.\n"
         "Hawaii hanya punya 34 tahun data dengan sedikit county, jadi angkanya kurang stabil.", fontsize=7.2, ha="left", color=ABU)
fig.subplots_adjust(left=0.17, right=0.97, top=0.85, bottom=0.12)
fig.savefig(OUT / "04_state_1980an_vs_2011_2020.png")
plt.close(fig)

print("Selesai. Chart tersimpan di:", OUT)
