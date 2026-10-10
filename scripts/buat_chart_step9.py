# ============================================================
# buat_chart_step9.py
# Membuat 2 chart README dari hasil query di sql/04_query_dasar.sql
#   - Chart 1: persen hari tidak sehat (AQI > 100) per state  (hasil 9B)
#   - Chart 2: distribusi kategori kualitas udara            (hasil 9C)
# Angka di bawah disalin dari hasil query, bukan dihitung ulang di Python.
# Cara jalan: python scripts/buat_chart_step9.py  (hasil masuk folder images)
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
    "axes.labelcolor": TEKS,
    "xtick.color": ABU,
    "ytick.color": TEKS,
})


def koma(x, desimal=1):
    """Format angka Indonesia: koma desimal."""
    return f"{x:.{desimal}f}".replace(".", ",")


def ribuan(n):
    """Format angka Indonesia: titik pemisah ribuan."""
    return f"{n:,}".replace(",", ".")


# ---------- Chart 1: persen hari tidak sehat per state ----------
# Hasil 9B, hanya 50 state (tanpa DC, Puerto Rico, Virgin Islands, Meksiko)
top15 = [
    ("California", 13.11), ("West Virginia", 13.11), ("Hawaii", 12.74),
    ("Delaware", 12.08), ("Arizona", 11.76), ("Indiana", 10.80),
    ("Tennessee", 10.32), ("Ohio", 9.52), ("Pennsylvania", 8.94),
    ("Maryland", 8.81), ("Connecticut", 8.56), ("Missouri", 8.26),
    ("New Jersey", 7.87), ("Illinois", 7.00), ("Massachusetts", 7.00),
]
# Rata-rata 50 state: (667.744 - 5.464) / (10.158.527 - 114.856) county-hari
rata_50 = (667744 - 2690 - 1457 - 458 - 859) / (10158527 - 10184 - 14927 - 16375 - 73370) * 100

nama = [n for n, _ in top15][::-1]
nilai = [v for _, v in top15][::-1]
warna = ["#B5694F" if v >= 13 else "#8AA3B5" for v in nilai]

fig, ax = plt.subplots(figsize=(8.4, 6.4), dpi=200)
fig.patch.set_facecolor("white")
bars = ax.barh(nama, nilai, color=warna, height=0.68)
for b, v in zip(bars, nilai):
    ax.text(v + 0.18, b.get_y() + b.get_height() / 2, koma(v, 1) + "%",
            va="center", ha="left", fontsize=9.5, color=TEKS)

ax.axvline(rata_50, color="#5F6B75", linewidth=1, linestyle=(0, (4, 3)), zorder=3)
ax.text(rata_50 + 0.12, -0.95, f"rata-rata 50 state: {koma(rata_50, 1)}%",
        fontsize=8.5, color=ABU, ha="left", va="center")

ax.set_xlim(0, 15.5)
ax.set_ylim(-1.4, len(nama) - 0.4)
ax.set_xticks([])
for s in ("top", "right", "bottom"):
    ax.spines[s].set_visible(False)
ax.spines["left"].set_color("#C9CFD4")
ax.tick_params(axis="y", length=0, labelsize=10)

fig.text(0.04, 0.945, "Di California dan West Virginia, 13% hari-county melewati AQI 100",
         fontsize=13.5, fontweight="bold", ha="left", color=TEKS)
fig.text(0.04, 0.905, "Dua kali lipat rata-rata 50 state. Persentase county-hari dengan AQI > 100, 15 state tertinggi, 1980 - Mei 2021",
         fontsize=9, ha="left", color=ABU)
fig.text(0.04, 0.025, "Sumber: EPA Historical Air Quality (Kaggle, threnjen); diolah dengan PostgreSQL. "
         "Satuan: satu county pada satu hari.", fontsize=7.5, ha="left", color=ABU)
fig.subplots_adjust(left=0.19, right=0.97, top=0.87, bottom=0.08)
fig.savefig(OUT / "01_persen_hari_tidak_sehat_per_state.png")
plt.close(fig)

# ---------- Chart 2: distribusi kategori ----------
# Hasil 9C
kategori = [
    ("Good", 7144209, 70.33, "#86A992"),
    ("Moderate", 2346574, 23.10, "#D6C486"),
    ("Unhealthy for\nSensitive Groups", 510449, 5.02, "#DDA878"),
    ("Unhealthy", 133075, 1.31, "#C9806A"),
    ("Very Unhealthy", 23047, 0.23, "#9A6176"),
    ("Hazardous", 1173, 0.01, "#6E5063"),
][::-1]

fig, ax = plt.subplots(figsize=(8.4, 4.6), dpi=200)
bars = ax.barh([k[0] for k in kategori], [k[2] for k in kategori],
               color=[k[3] for k in kategori], height=0.64)
for b, k in zip(bars, kategori):
    ax.text(k[2] + 1.0, b.get_y() + b.get_height() / 2,
            f"{koma(k[2], 2)}%  ({ribuan(k[1])} county-hari)",
            va="center", ha="left", fontsize=9.2, color=TEKS)

ax.set_xlim(0, 118)
ax.set_xticks([])
for s in ("top", "right", "bottom"):
    ax.spines[s].set_visible(False)
ax.spines["left"].set_color("#C9CFD4")
ax.tick_params(axis="y", length=0, labelsize=9.5)

fig.text(0.04, 0.925, "70% county-hari berkategori Good; hanya 6,6% melewati AQI 100",
         fontsize=13, fontweight="bold", ha="left", color=TEKS)
fig.text(0.04, 0.865, "Distribusi kategori kualitas udara, 10.158.527 county-hari, 1980 - Mei 2021",
         fontsize=9, ha="left", color=ABU)
fig.text(0.04, 0.03, "Sumber: EPA Historical Air Quality (Kaggle, threnjen); diolah dengan PostgreSQL.",
         fontsize=7.5, ha="left", color=ABU)
fig.subplots_adjust(left=0.20, right=0.97, top=0.82, bottom=0.10)
fig.savefig(OUT / "02_distribusi_kategori.png")
plt.close(fig)

print("Selesai. Chart tersimpan di:", OUT)
