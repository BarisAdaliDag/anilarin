"""Popsa sahne arka planlarından (elle tutulan beyaz kitap) kapak yerleştirme katmanları üretir.

Her BACKGROUND_PBKn (kitap) ve BACKGROUND_PTSn (baskı) için:
  <kod>_OVERLAY.png : kitap/kâğıt yüzeyi saydam (hafif gölgeli), eller ve masa opak. Kapağın üstüne çizilir.
  rects.json        : kitabın sahnedeki dikdörtgeni (0..1 oranları).
Kullanım: python tool/make_scene_overlays.py <topdownscene klasörü> <çıktı klasörü>
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

src, dst = Path(sys.argv[1]), Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
rects = {}
for kind, n in [("PBK", n) for n in range(1, 13)] + [("PTS", n) for n in range(2, 9)]:
    f = src / f"BACKGROUND_{kind}{n}.webp"
    if not f.exists():
        continue
    rgb = np.asarray(Image.open(f).convert("RGB")).astype(np.float32)
    lo, hi = rgb.min(axis=2), rgb.max(axis=2)
    # Kitap yüzeyi: açık ve renksiz pikseller
    book = np.clip((lo - 185) / 30, 0, 1) * np.clip((40 - (hi - lo)) / 20, 0, 1)
    ys, xs = np.nonzero(book > 0.9)
    x0, x1 = np.percentile(xs, [0.5, 99.5])
    y0, y1 = np.percentile(ys, [0.5, 99.5])
    h, w = book.shape
    inside = np.zeros_like(book)
    inside[int(y0):int(y1) + 1, int(x0):int(x1) + 1] = 1
    b = book * inside
    lum = rgb.mean(axis=2)
    shade = np.clip(1 - lum / np.percentile(lum[b > 0.9], 98), 0, 0.6)
    alpha = (1 - b) + b * shade
    color = rgb * (1 - b)[..., None]  # kitap bölgesinde siyah (gölge)
    if kind == "PTS":
        # Baskı destesi yerine düz masa: destenin çevresindeki kutu, aynı satırın kutu dışındaki
        # ahşap dokusuyla (damarlar yatay) yeniden çizilir; sahneden yalnız el korunur.
        bx0, bx1 = max(0, int(x0 - (x1 - x0) * 0.25)), min(w, int(x1 + (x1 - x0) * 0.25))
        by0, by1 = max(0, int(y0 - (y1 - y0) * 0.25)), min(h, int(y1 + (y1 - y0) * 0.1))
        bw = bx1 - bx0
        recon = rgb.copy()
        # Kutu iki yandan aynalanır (soldaki ve sağdaki masa) ve konuma göre harmanlanır; sahnenin
        # kenar kararması yumuşak olduğundan ek yeri görünmez.
        for x in range(bx0, bx1):
            t = (x - bx0) / max(1, bw - 1)
            lx = max(0, bx0 - 1 - (x - bx0) % max(1, bx0))
            rx = min(w - 1, bx1 + (bx1 - 1 - x) % max(1, w - bx1))
            recon[by0:by1, x] = (1 - t) * rgb[by0:by1, lx] + t * rgb[by0:by1, rx]
        diff = np.abs(rgb - recon).mean(axis=2)
        chroma = hi - lo
        # Ten masadan daha doygun (masa ~36-41); kenar yumuşasın diye bir piksel genişletilir.
        hand = (diff > 18) & (chroma >= 50)
        hand = hand | np.roll(hand, 1, 0) | np.roll(hand, -1, 0) | np.roll(hand, 1, 1) | np.roll(hand, -1, 1)
        hand[: int(y0 + (y1 - y0) * 0.6)] = False  # el destenin alt kısmından girer
        box = np.zeros((h, w), bool)
        box[by0:by1, bx0:bx1] = True
        color = np.where(box[..., None], recon, color)
        alpha = np.where(box, 1.0, alpha)
        card = inside > 0
        alpha = np.where(card, 0.0, alpha)
        color = np.where(hand[..., None], rgb, color)
        alpha = np.where(hand, 1.0, alpha)
    out = np.dstack([color, alpha * 255]).astype(np.uint8)
    img = Image.fromarray(out, "RGBA")
    img = img.resize((640, round(640 * h / w)), Image.LANCZOS)  # kartlar küçük; dosya hafif kalsın
    img.save(dst / f"{kind}-{n}_OVERLAY.png", optimize=True)
    rects[f"{kind}-{n}"] = [round(x0 / w, 4), round(y0 / h, 4), round(x1 / w, 4), round(y1 / h, 4)]
(dst / "rects.json").write_text(json.dumps(rects, indent=1))
print(f"{len(rects)} sahne → {dst}")
